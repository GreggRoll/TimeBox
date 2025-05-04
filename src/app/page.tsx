'use client';

import React, {useState, useEffect} from 'react';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Settings as SettingsIcon, User as UserIcon } from 'lucide-react';
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

const Home = () => {
  const [date, setDate] = useState<Date | undefined>(new Date());
  const [topPriorities, setTopPriorities] = useState(['', '', '']);
  const [brainDump, setBrainDump] = useState('');
  const [startTime, setStartTime] = useState(5);
  const [endTime, setEndTime] = useState(23);
  const {theme, setTheme} = useTheme();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [isSignedIn, setIsSignedIn] = useState(false); // Placeholder for sign-in status

  const timeSlots = Array.from(
    {length: endTime - startTime + 1},
    (_, i) => startTime + i
  );

  return (
    <>
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
              className="h-10 w-10 mr-2"
            >
              <rect width="18" height="18" x="3" y="3" rx="2" ry="2" />
              <line x1="9" x2="15" y1="3" y2="21" />
            </svg>
            <h1 className="text-2xl font-bold">The Time Box.</h1>
          </div>
          <div className="flex items-center space-x-2">
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Dialog open={settingsOpen} onOpenChange={setSettingsOpen}>
                    <DialogTrigger asChild>
                      <Button
                        variant="ghost"
                        className="rounded-full p-2 hover:bg-accent"
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
                            onChange={e =>
                              setStartTime(parseInt(e.target.value))
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
                            onChange={e => setEndTime(parseInt(e.target.value))}
                            className="col-span-3"
                          />
                        </div>
                      </div>
                      <DialogFooter>
                        <Button type="submit" onClick={() => setSettingsOpen(false)}>
                          Save
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>
                </TooltipTrigger>
                <TooltipContent>Settings</TooltipContent>
              </Tooltip>
            </TooltipProvider>
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
                    <DialogTrigger asChild>
                      <Button
                        variant="ghost"
                        className="rounded-full p-2 hover:bg-accent"
                      >
                        <UserIcon size={20} />
                      </Button>
                    </DialogTrigger>
                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>
                          {isSignedIn ? 'Profile' : 'Sign In / Sign Up'}
                        </DialogTitle>
                      </DialogHeader>
                      {isSignedIn ? (
                        // Signed-in state: show calendar
                        <div className="grid gap-4 py-4">
                           <Label>Select Date</Label>
                          <Popover>
                            <PopoverTrigger asChild>
                              <Button
                                variant={'outline'}
                                className={cn(
                                  'w-[240px] justify-start text-left font-normal',
                                  !date && 'text-muted-foreground'
                                )}
                              >
                                {date ? (
                                  format(date, 'PPP')
                                ) : (
                                  <span>Pick a date</span>
                                )}
                              </Button>
                            </PopoverTrigger>
                            <PopoverContent
                              className="w-auto p-0"
                              align="start"
                              side="bottom"
                            >
                              <Calendar
                                mode="single"
                                selected={date}
                                onSelect={setDate}
                                disabled={futureDate =>
                                  futureDate > new Date() ||
                                  futureDate < new Date('2024-01-01')
                                }
                                initialFocus
                              />
                            </PopoverContent>
                          </Popover>
                        </div>
                      ) : (
                        // Not signed-in state: show sign-in/up prompts
                        <div className="grid gap-4 py-4">
                          <p>
                            Please sign in or sign up to access your profile and
                            past time boxes.
                          </p>
                          <Button onClick={() => setIsSignedIn(true)}>
                            Sign In / Sign Up (Placeholder)
                          </Button>
                        </div>
                      )}
                      <DialogFooter>
                        <Button type="submit" onClick={() => setProfileOpen(false)}>
                          Close
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>
                </TooltipTrigger>
                <TooltipContent>Profile</TooltipContent>
              </Tooltip>
           </TooltipProvider>
          </div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row h-[calc(100vh-65px)]"> {/* Adjusted height */}
        <div className="md:w-1/2 p-4 border-r"> {/* Left pane */}
          <div className="mb-4">
            <h2 className="text-lg font-semibold mb-2">Top Priorities</h2>
            {topPriorities.map((priority, index) => (
              <Input
                key={index}
                type="text"
                placeholder={`Priority ${index + 1}`}
                value={priority}
                onChange={e => {
                  const newPriorities = [...topPriorities];
                  newPriorities[index] = e.target.value;
                  setTopPriorities(newPriorities);
                }}
                className="mb-1"
              />
            ))}
          </div>

          <div className="mb-4">
            <h2 className="text-lg font-semibold mb-2">Brain Dump</h2>
            <Textarea
              placeholder="Enter your thoughts here..."
              value={brainDump}
              onChange={e => setBrainDump(e.target.value)}
              className="h-40" // Consider making this resizeable or taller
            />
          </div>
        </div>

        <div className="md:w-1/2 p-4"> {/* Right pane */}
          <div className="mb-4">
             <label className="block text-sm font-medium text-gray-700 mb-1">
              Date:
            </label>
            <span className="text-lg font-semibold">
              {date ? format(date, 'PPP') : 'No date selected'}
            </span>
          </div>
          <div className="grid">
             {/* Grid for Time Slots */}
            <div className="grid grid-cols-[max-content_1fr_1fr] gap-x-2 gap-y-1 items-center">
               {/* Header Row */}
                <div className="font-semibold justify-self-center"></div>
                <div className="font-semibold justify-self-center">:00</div>
                <div className="font-semibold justify-self-center">:30</div>

                 {/* Time Slot Rows */}
                {timeSlots.map(time => (
                    <React.Fragment key={time}>
                    <div className="text-sm font-medium justify-self-center self-center pr-2">{time}</div>
                    <Input type="text" placeholder="Task" className="time-slot mb-1" />
                    <Input type="text" placeholder="Task" className="time-slot mb-1" />
                    </React.Fragment>
                ))}
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
