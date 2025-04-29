'use client';

import React, {useState, useRef, useEffect} from 'react';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Progress} from '@/components/ui/progress';
import {cn} from '@/lib/utils';
import {Play, Pause, RefreshCw, Settings} from 'lucide-react';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import {Switch} from '@/components/ui/switch';

interface TimerControlsProps {
  isRunning: boolean;
  onStart: () => void;
  onPause: () => void;
  onReset: () => void;
}

const TimerControls: React.FC<TimerControlsProps> = ({
  isRunning,
  onStart,
  onPause,
  onReset,
}) => {
  return (
    <div className="flex items-center justify-center space-x-4">
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              onClick={isRunning ? onPause : onStart}
              className="rounded-full p-2 hover:bg-accent"
            >
              {isRunning ? <Pause size={20} /> : <Play size={20} />}
            </button>
          </TooltipTrigger>
          <TooltipContent>
            {isRunning ? 'Pause Timer' : 'Start Timer'}
          </TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <button onClick={onReset} className="rounded-full p-2 hover:bg-accent">
              <RefreshCw size={20} />
            </button>
          </TooltipTrigger>
          <TooltipContent>Reset Timer</TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </div>
  );
};

const TimeBoxDisplay: React.FC<{
  duration: number;
  timeRemaining: number;
}> = ({duration, timeRemaining}) => {
  const progress = ((duration * 60 - timeRemaining) / (duration * 60)) * 100;

  return (
    <div className="relative h-64 w-64">
      <svg className="absolute h-full w-full">
        <circle
          className="text-gray-300"
          strokeWidth="6"
          stroke="currentColor"
          fill="transparent"
          r="100"
          cx="125"
          cy="125"
        />
        <circle
          className="text-teal-500"
          strokeWidth="6"
          strokeDasharray={`${2 * Math.PI * 100}`}
          style={{
            strokeDashoffset: `${2 * Math.PI * 100 * (1 - progress / 100)}`,
            transition: 'stroke-dashoffset 0.3s ease 0s',
          }}
          stroke="currentColor"
          fill="transparent"
          r="100"
          cx="125"
          cy="125"
        />
      </svg>
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-center">
        <div className="text-4xl font-bold">
          {Math.floor(timeRemaining / 60)}:{String(timeRemaining % 60).padStart(2, '0')}
        </div>
        <div className="text-sm text-gray-500">Remaining</div>
      </div>
    </div>
  );
};

const SettingsModal: React.FC<{
  open: boolean;
  onOpenChange: (open: boolean) => void;
  soundEnabled: boolean;
  setSoundEnabled: (enabled: boolean) => void;
}> = ({open, onOpenChange, soundEnabled, setSoundEnabled}) => {
  return (
    <div className="flex items-center space-x-2">
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              className="rounded-full p-2 hover:bg-accent"
              onClick={() => onOpenChange(true)}
            >
              <Settings size={20} />
            </button>
          </TooltipTrigger>
          <TooltipContent>Settings</TooltipContent>
        </Tooltip>
      </TooltipProvider>
      <div className="flex items-center space-x-2">
        <Switch
          id="sound"
          checked={soundEnabled}
          onCheckedChange={setSoundEnabled}
        />
      </div>
    </div>
  );
};

export default function Home() {
  const [date, setDate] = useState('');
  const [topPriorities, setTopPriorities] = useState(['', '', '']);
  const [brainDump, setBrainDump] = useState('');
  const [duration, setDuration] = useState(25); // Default duration in minutes
  const [timeRemaining, setTimeRemaining] = useState(duration * 60); // Time in seconds
  const [isRunning, setIsRunning] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const audioRef = useRef<HTMLAudioElement>(null);

  const timeSlots = Array.from({length: 19}, (_, i) => i + 5); // Times from 5 to 23

  useEffect(() => {
    let intervalId: NodeJS.Timeout;

    if (isRunning) {
      intervalId = setInterval(() => {
        setTimeRemaining(prevTime => {
          if (prevTime <= 0) {
            clearInterval(intervalId);
            setIsRunning(false);
            if (soundEnabled) {
              audioRef.current?.play();
            }
            return 0;
          }
          return prevTime - 1;
        });
      }, 1000);
    }

    return () => clearInterval(intervalId);
  }, [isRunning, soundEnabled]);

  const startTimer = () => {
    setIsRunning(true);
  };

  const pauseTimer = () => {
    setIsRunning(false);
  };

  const resetTimer = () => {
    setIsRunning(false);
    setTimeRemaining(duration * 60);
  };

  const handleDurationChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newDuration = parseInt(e.target.value, 10);
    if (!isNaN(newDuration) && newDuration > 0) {
      setDuration(newDuration);
      setTimeRemaining(newDuration * 60);
    }
  };

  return (
    <div className="timebox-container">
      <div className="timebox-left">
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <svg
              width="40"
              height="40"
              viewBox="0 0 24 24"
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
          <SettingsModal
            open={settingsOpen}
            onOpenChange={setSettingsOpen}
            soundEnabled={soundEnabled}
            setSoundEnabled={setSoundEnabled}
          />
        </div>

        <div className="mb-4 flex flex-col items-center">
          <TimeBoxDisplay duration={duration} timeRemaining={timeRemaining} />
          <TimerControls
            isRunning={isRunning}
            onStart={startTimer}
            onPause={pauseTimer}
            onReset={resetTimer}
          />
          <div className="mt-2">
            <Input
              type="number"
              placeholder="Duration (minutes)"
              value={duration}
              onChange={handleDurationChange}
              className="w-40"
            />
          </div>
        </div>

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
          <div className="font-semibold"></div>
          <div className="font-semibold">:00</div>
          <div className="font-semibold">:30</div>
          {timeSlots.map(time => (
            <React.Fragment key={time}>
              <div>{time}</div>
              <Input type="text" placeholder="Task" className="time-slot" />
              <Input type="text" placeholder="Task" className="time-slot" />
            </React.Fragment>
          ))}
        </div>
      </div>
      <audio ref={audioRef} src="/notification.mp3" preload="auto" />
    </div>
  );
}
