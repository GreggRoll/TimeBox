
'use client';

import React, {useState, useEffect, useCallback, useMemo} from 'react';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Settings as SettingsIcon, User as UserIcon, LogOut, Calendar as CalendarIcon } from 'lucide-react'; // Added LogOut and CalendarIcon
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogTitle,
  DialogHeader,
  DialogFooter,
  DialogDescription, // Added DialogDescription
} from '@/components/ui/dialog';
import {Label} from '@/components/ui/label';
import {Button} from '@/components/ui/button';
import {useTheme} from 'next-themes';
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {Calendar} from '@/components/ui/calendar';
import {Popover, PopoverContent, PopoverTrigger} from '@/components/ui/popover';
import {cn} from '@/lib/utils';
import {format} from 'date-fns';
import { useAuthState, signInWithGoogle, logout } from '@/lib/firebase'; // Import Firebase auth functions
import { saveTimeboxData, getTimeboxData, TimeboxData } from '@/lib/firestore'; // Import Firestore functions
import { Skeleton } from '@/components/ui/skeleton'; // Import Skeleton

// Debounce function
function debounce<F extends (...args: any[]) => any>(func: F, waitFor: number) {
  let timeoutId: NodeJS.Timeout | null = null;

  return (...args: Parameters<F>): Promise<ReturnType<F>> =>
    new Promise((resolve) => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout(() => {
        timeoutId = null; // Clear timeoutId after execution
        resolve(func(...args));
      }, waitFor);
    });
}


const Home = () => {
  // Initialize date state to undefined to prevent hydration mismatch
  const [date, setDate] = useState<Date | undefined>(undefined);
  const [topPriorities, setTopPriorities] = useState<string[]>(['', '', '']);
  const [brainDump, setBrainDump] = useState<string>('');
  const [startTime, setStartTime] = useState<number>(5);
  const [endTime, setEndTime] = useState<number>(23);
  const {theme, setTheme} = useTheme();
  const [settingsOpen, setSettingsOpen] = useState<boolean>(false);
  const [profileOpen, setProfileOpen] = useState<boolean>(false);
  const { user, loading: authLoading } = useAuthState(); // Use Firebase auth state
  const [timeSlotTasks, setTimeSlotTasks] = useState<{ [time: number]: { '00'?: string; '30'?: string } }>({});
  const [dataLoading, setDataLoading] = useState<boolean>(false);
  const [displayDate, setDisplayDate] = useState<Date | undefined>(undefined); // Separate state for display


   const formattedDate = useMemo(() => date ? format(date, 'yyyy-MM-dd') : '', [date]);

   // Set initial date on client-side after hydration
   useEffect(() => {
    const initialDate = new Date();
     setDate(initialDate);
     setDisplayDate(initialDate); // Also set initial display date
   }, []);

  // Debounced save function
  const debouncedSaveData = useCallback(
    debounce(async (userId: string, dateStr: string, data: Partial<TimeboxData>) => {
       if (userId && dateStr) {
          await saveTimeboxData(userId, dateStr, data);
       }
    }, 1000), // Debounce time of 1 second
    []
  );

  // Load data from Firestore based on the selected date
  useEffect(() => {
    if (user && formattedDate && !authLoading) {
      setDataLoading(true);
      getTimeboxData(user.uid, formattedDate).then(data => {
        if (data) {
          setTopPriorities(data.topPriorities || ['', '', '']);
          setBrainDump(data.brainDump || '');
          setTimeSlotTasks(data.timeSlotTasks || {});
        } else {
           // Reset to default if no data found for the date
           setTopPriorities(['', '', '']);
           setBrainDump('');
           setTimeSlotTasks({});
        }
        setDataLoading(false);
        if(date) setDisplayDate(date); // Update display date when data is loaded for it
      });
    } else if (!user && !authLoading) {
        // Reset fields if user logs out or no date selected yet
        setTopPriorities(['', '', '']);
        setBrainDump('');
        setTimeSlotTasks({});
        setDataLoading(false); // Ensure loading is false
    }
     // Don't reload data just because displayDate changes
  }, [user, formattedDate, authLoading, date]); // Depend on user, formattedDate, authLoading, and the actual selected date


  // Save data to Firestore when state changes (debounced)
  useEffect(() => {
    // Prevent saving initial empty/default state before data loading or if user logs out
     if (user && formattedDate && !authLoading && !dataLoading && date) {
       debouncedSaveData(user.uid, formattedDate, { topPriorities, brainDump, timeSlotTasks });
    }
  }, [topPriorities, brainDump, timeSlotTasks, user, formattedDate, authLoading, dataLoading, date, debouncedSaveData]); // Include date


  const timeSlots = useMemo(() => Array.from(
    {length: Math.max(0, endTime - startTime + 1)}, // Ensure length is not negative
    (_, i) => startTime + i
  ), [startTime, endTime]);

  const handlePriorityChange = (index: number, value: string) => {
    const newPriorities = [...topPriorities];
    newPriorities[index] = value;
    setTopPriorities(newPriorities);
  };

  const handleBrainDumpChange = (value: string) => {
    setBrainDump(value);
  };

   const handleTimeSlotChange = (time: number, halfHour: '00' | '30', value: string) => {
    setTimeSlotTasks(prevTasks => ({
      ...prevTasks,
      [time]: {
        ...(prevTasks[time] || {}),
        [halfHour]: value,
      },
    }));
  };

 const handleDateChange = (newDate: Date | undefined) => {
    if (newDate) {
        setDate(newDate); // Update the date used for data fetching/saving
        // Display date will update in the useEffect for data loading
        setProfileOpen(false); // Close profile modal on date selection
    }
 };


  return (
    <TooltipProvider> {/* Wrap entire component with TooltipProvider */}
      <div className="bg-background border-b sticky top-0 z-10">
        <div className="flex items-center justify-between p-4">
          <div className="flex items-center">
            <svg
              width="40"
              height="40"
              viewBox="0 0 24 24" // Corrected viewBox
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="h-10 w-10 mr-2 text-primary" // Use theme color
            >
              <rect width="18" height="18" x="3" y="3" rx="2" ry="2" />
              <line x1="9" x2="15" y1="3" y2="21" />
               {/* Simple Clock face */}
              <circle cx="12" cy="12" r="4" />
              <polyline points="12 9 12 12 15 12" />
            </svg>
            <h1 className="text-2xl font-bold">The Time Box.</h1>
          </div>
          <div className="flex items-center space-x-2">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Dialog open={settingsOpen} onOpenChange={setSettingsOpen}>
                    <DialogTrigger asChild>
                      <Button
                        variant="ghost"
                        className="rounded-full p-2 hover:bg-accent"
                        aria-label="Settings"
                      >
                        <SettingsIcon size={20} />
                      </Button>
                    </DialogTrigger>
                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>Settings</DialogTitle>
                      </DialogHeader>
                      <div className="grid gap-4 py-4">
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="theme" className="text-right">
                            Theme
                          </Label>
                          <Select
                            onValueChange={setTheme}
                            defaultValue={theme}
                          >
                            <SelectTrigger className="w-[180px]">
                              <SelectValue placeholder="Theme" />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectGroup>
                                <SelectLabel>Theme</SelectLabel>
                                <SelectItem value="light">Light</SelectItem>
                                <SelectItem value="dark">Dark</SelectItem>
                                <SelectItem value="system">System</SelectItem>
                              </SelectGroup>
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="start-time" className="text-right">
                            Start Time
                          </Label>
                          <Input
                            type="number"
                            id="start-time"
                            value={startTime}
                            min="0"
                            max="23"
                            onChange={e =>
                              setStartTime(Math.max(0, Math.min(23, parseInt(e.target.value) || 0)))
                            }
                            className="col-span-3"
                          />
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="end-time" className="text-right">
                            End Time
                          </Label>
                          <Input
                            type="number"
                            id="end-time"
                            value={endTime}
                             min="0"
                             max="23"
                            onChange={e => setEndTime(Math.max(0, Math.min(23, parseInt(e.target.value) || 0)))}
                            className="col-span-3"
                          />
                        </div>
                      </div>
                      <DialogFooter>
                        <Button onClick={() => setSettingsOpen(false)}>
                          Close
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>
                </TooltipTrigger>
                <TooltipContent>Settings</TooltipContent>
              </Tooltip>

              <Tooltip>
                <TooltipTrigger asChild>
                  <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
                    <DialogTrigger asChild>
                      <Button
                        variant="ghost"
                        className="rounded-full p-2 hover:bg-accent"
                         aria-label="Profile"
                      >
                        <UserIcon size={20} />
                      </Button>
                    </DialogTrigger>
                     <DialogContent>
                      <DialogHeader>
                        <DialogTitle>
                          {authLoading ? 'Loading...' : user ? 'Profile & Date Select' : 'Sign In'}
                        </DialogTitle>
                        <DialogDescription>
                           {authLoading ? '' : user ? 'Select a date to view or edit your timebox.' : 'Sign in with Google to save and access your timeboxes across devices.'}
                        </DialogDescription>
                      </DialogHeader>
                      {authLoading ? (
                        <div className="flex justify-center items-center p-4">
                           <Skeleton className="h-8 w-24" />
                        </div>

                      ) : user ? (
                        // Signed-in state: show calendar and logout
                        <div className="grid gap-4 py-4">
                           <Label className="text-center mb-2">Select Date</Label>
                            <Calendar
                              mode="single"
                              selected={date} // Use the actual selected date for the calendar
                              onSelect={handleDateChange} // Use handler to update date and close modal
                              disabled={(day) => day > new Date()} // Disable future dates
                              initialFocus
                              className="mx-auto" // Center the calendar
                            />
                           <Button variant="outline" onClick={logout} className="mt-4">
                             <LogOut className="mr-2 h-4 w-4" /> Sign Out
                           </Button>
                        </div>
                      ) : (
                        // Not signed-in state: show sign-in button
                        <div className="grid gap-4 py-4">
                          <Button onClick={signInWithGoogle}>
                             <svg className="mr-2 h-4 w-4" aria-hidden="true" focusable="false" data-prefix="fab" data-icon="google" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 488 512"><path fill="currentColor" d="M488 261.8C488 403.3 381.5 512 244.8 512 112.8 512 0 398.5 0 256S112.8 0 244.8 0c69.8 0 130.5 28.7 173.4 74.5l-64.8 64.8C314.6 99.8 283.8 80 244.8 80c-82.3 0-148.5 67.3-148.5 150.5S162.5 381 244.8 381c47.3 0 87.7-20.4 116.1-53.7l64.8 64.8C411.1 469 335.8 512 244.8 512z"></path></svg>
                            Sign In with Google
                          </Button>
                        </div>
                      )}
                      <DialogFooter>
                        <Button variant="secondary" onClick={() => setProfileOpen(false)}>
                          Close
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>
                </TooltipTrigger>
                <TooltipContent>Profile</TooltipContent>
              </Tooltip>
          </div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row h-[calc(100vh-65px)]"> {/* Adjusted height */}
        {/* Left Pane */}
        <div className="md:w-1/2 p-4 border-r overflow-y-auto">
           {/* Date Display Moved Here */}
           <div className="mb-4 flex items-center">
             <CalendarIcon className="mr-2 h-5 w-5 text-muted-foreground" />
             <span className="text-lg font-semibold">
               {/* Always render the span, show placeholder if date is not set yet */}
               {displayDate ? format(displayDate, 'PPP') : 'Loading date...'}
             </span>
           </div>

           {/* Top Priorities */}
          <div className="mb-4">
            <h2 className="text-lg font-semibold mb-2">Top Priorities</h2>
            {dataLoading ? (
               Array.from({ length: 3 }).map((_, index) => (
                    <Skeleton key={index} className="h-10 w-full mb-1" />
                ))
            ) : (
                topPriorities.map((priority, index) => (
                  <Input
                    key={index}
                    type="text"
                    placeholder={`Priority ${index + 1}`}
                    value={priority}
                    onChange={e => handlePriorityChange(index, e.target.value)}
                    className="mb-1"
                    disabled={!user || authLoading} // Disable if not logged in or auth loading
                  />
                ))
            )}
          </div>

           {/* Brain Dump */}
          <div className="mb-4">
            <h2 className="text-lg font-semibold mb-2">Brain Dump</h2>
             {dataLoading ? (
                <Skeleton className="h-40 w-full" />
             ) : (
                <Textarea
                  placeholder={user ? "Enter your thoughts here..." : "Sign in to start planning"}
                  value={brainDump}
                  onChange={e => handleBrainDumpChange(e.target.value)}
                  className="h-40" // Consider making this resizeable or taller
                   disabled={!user || authLoading} // Disable if not logged in or auth loading
                />
             )}
          </div>
        </div>

         {/* Right Pane - Time Slots */}
         <div className="md:w-1/2 p-4 overflow-y-auto">
           <div className="time-slots" style={{ gridTemplateColumns: 'max-content 1fr 1fr' }}>
             {/* Header Row */}
             <div className="font-semibold justify-self-center"></div> {/* Empty cell for alignment */}
             <div className="font-semibold justify-self-center pb-1">:00</div>
             <div className="font-semibold justify-self-center pb-1">:30</div>

             {/* Time Slot Rows */}
             {timeSlots.map(time => (
               <React.Fragment key={time}>
                 {/* Time Label */}
                 <div className="text-sm font-medium justify-self-center self-center pr-2">{time}</div>

                 {/* :00 Task Input */}
                 {dataLoading ? (
                   <Skeleton className="h-10 w-full time-slot mb-1" />
                 ) : (
                    <Input
                        type="text"
                        placeholder="Task"
                        value={timeSlotTasks[time]?.['00'] || ''}
                        onChange={(e) => handleTimeSlotChange(time, '00', e.target.value)}
                        className="time-slot mb-1"
                        disabled={!user || authLoading} // Disable if not logged in or auth loading
                    />
                 )}


                 {/* :30 Task Input */}
                  {dataLoading ? (
                     <Skeleton className="h-10 w-full time-slot mb-1" />
                 ) : (
                    <Input
                        type="text"
                        placeholder="Task"
                        value={timeSlotTasks[time]?.['30'] || ''}
                        onChange={(e) => handleTimeSlotChange(time, '30', e.target.value)}
                        className="time-slot mb-1"
                        disabled={!user || authLoading} // Disable if not logged in or auth loading
                    />
                 )}
               </React.Fragment>
             ))}
           </div>
         </div>
      </div>
    </TooltipProvider>
  );
};

export default Home;

    