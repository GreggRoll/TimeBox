'use client';

import React, {useState, useEffect} from 'react';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Settings as SettingsIcon} from 'lucide-react';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import {Switch} from '@/components/ui/switch';
import {Dialog, DialogTrigger, DialogContent, DialogTitle, DialogDescription, DialogHeader, DialogFooter} from "@/components/ui/dialog"
import {Label} from "@/components/ui/label"
import {Button} from "@/components/ui/button"
import { useTheme } from 'next-themes'
import { Select, SelectContent, SelectGroup, SelectItem, SelectLabel, SelectTrigger, SelectValue } from '@/components/ui/select';

const Home = () => {
  const [date, setDate] = useState('');
  const [topPriorities, setTopPriorities] = useState(['', '', '']);
  const [brainDump, setBrainDump] = useState('');
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [startTime, setStartTime] = useState(5);
  const [endTime, setEndTime] = useState(23);
  const { theme, setTheme } = useTheme();
   const [open, setOpen] = React.useState(false)


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
              viewBox="0 0 24 0 24"
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
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Dialog open={open} onOpenChange={setOpen}>
                  <DialogTrigger asChild>
                    <Button variant="ghost" className="rounded-full p-2 hover:bg-accent">
                      <SettingsIcon size={20} />
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Settings</DialogTitle>
                      <DialogDescription>
                        Adjust settings to your preference.
                      </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="theme" className="text-right">
                          Theme
                        </Label>
                           <Select onValueChange={setTheme} defaultValue={theme}>
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
                          onChange={(e) => setStartTime(parseInt(e.target.value))}
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
                          onChange={(e) => setEndTime(parseInt(e.target.value))}
                          className="col-span-3"
                        />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button type="submit" onClick={() => setOpen(false)}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </TooltipTrigger>
              <TooltipContent>Settings</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
      </div>

      <div className="timebox-container">
        <div className="timebox-left">
          <div className="top-priorities">
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

          <div className="brain-dump">
            <h2 className="text-lg font-semibold mb-2">Brain Dump</h2>
            <Textarea
              placeholder="Enter your thoughts here..."
              value={brainDump}
              onChange={e => setBrainDump(e.target.value)}
              className="h-40"
            />
          </div>
        </div>

        <div className="timebox-right">
          <div>
            <label htmlFor="date" className="block text-sm font-medium text-gray-700">
              Date:
            </label>
            <Input
              type="date"
              id="date"
              value={date}
              onChange={e => setDate(e.target.value)}
              className="mb-4"
            />
          </div>
          <div className="time-slots">
             <div className="grid grid-cols-3">
                <div className="font-semibold"></div>
                <div className="font-semibold justify-self-center">:00</div>
                <div className="font-semibold justify-self-center">:30</div>
                 {timeSlots.map(time => (
                  <React.Fragment key={time}>
                    <div>{time}</div>
                    <Input type="text" placeholder="Task" className="time-slot" />
                    <Input type="text" placeholder="Task" className="time-slot" />
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
