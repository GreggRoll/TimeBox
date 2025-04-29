'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { cn } from '@/lib/utils';
import { Play, Pause, RefreshCw, Settings } from 'lucide-react';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

const TimerDisplay: React.FC<{ duration: number; timeLeft: number }> = ({ duration, timeLeft }) => {
  const progress = (timeLeft / duration) * 100;
  const minutes = Math.floor(timeLeft / 60);
  const seconds = timeLeft % 60;

  return (
    <div className="relative w-80 h-80 mx-auto">
      <Progress value={100 - progress} className="absolute top-0 left-0 w-full h-full rounded-full bg-timer-background" />
      <Progress value={progress} className="absolute top-0 left-0 w-full h-full rounded-full transform rotate-90" />
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-3xl font-bold">
        {String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
      </div>
    </div>
  );
};

const TimerControls: React.FC<{
  duration: number;
  setDuration: (duration: number) => void;
  startTimer: () => void;
  pauseTimer: () => void;
  resetTimer: () => void;
  isRunning: boolean;
}> = ({ duration, setDuration, startTimer, pauseTimer, resetTimer, isRunning }) => {
  return (
    <div className="flex flex-col items-center space-y-4">
      <div className="flex items-center space-x-2">
        <Input
          type="number"
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
          className="w-24 text-center"
        />
        <span>minutes</span>
      </div>
      <div className="flex space-x-4">
       <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="outline" onClick={startTimer} disabled={isRunning}>
                <Play className="h-4 w-4 mr-2" />
                Start
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              Start TimeWise
            </TooltipContent>
          </Tooltip>
        </TooltipProvider>
        <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="outline" onClick={pauseTimer} disabled={!isRunning}>
                <Pause className="h-4 w-4 mr-2" />
                Pause
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              Pause TimeWise
            </TooltipContent>
          </Tooltip>
        </TooltipProvider>
        <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="outline" onClick={resetTimer}>
                <RefreshCw className="h-4 w-4 mr-2" />
                Reset
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              Reset TimeWise
            </TooltipContent>
          </Tooltip>
        </TooltipProvider>
      </div>
    </div>
  );
};

const SettingsComponent: React.FC<{ soundEnabled: boolean; setSoundEnabled: (enabled: boolean) => void }> = ({
  soundEnabled,
  setSoundEnabled,
}) => {
  return (
    <div className="flex items-center space-x-2">
      <span>Notification Sound:</span>
      <Switch checked={soundEnabled} onCheckedChange={setSoundEnabled} />
    </div>
  );
};

export default function Home() {
  const [duration, setDuration] = useState(25);
  const [timeLeft, setTimeLeft] = useState(duration * 60);
  const [isRunning, setIsRunning] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const timerId = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    setTimeLeft(duration * 60);
  }, [duration]);

  useEffect(() => {
    if (isRunning && timeLeft > 0) {
      timerId.current = setInterval(() => {
        setTimeLeft((prevTimeLeft) => prevTimeLeft - 1);
      }, 1000);
    } else if (timeLeft === 0) {
      clearInterval(timerId.current as NodeJS.Timeout);
      setIsRunning(false);
      if (soundEnabled) {
        new Audio('/notification.mp3').play();
      }
    } else {
      clearInterval(timerId.current as NodeJS.Timeout);
    }

    return () => clearInterval(timerId.current as NodeJS.Timeout);
  }, [isRunning, timeLeft, soundEnabled]);

  const startTimer = () => {
    setIsRunning(true);
  };

  const pauseTimer = () => {
    setIsRunning(false);
  };

  const resetTimer = () => {
    setIsRunning(false);
    setTimeLeft(duration * 60);
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-background p-4">
      <Card className="w-full max-w-md">
        <CardContent className="flex flex-col space-y-6">
          <h1 className="text-2xl font-bold text-center">TimeWise</h1>
          <TimerDisplay duration={duration * 60} timeLeft={timeLeft} />
          <TimerControls
            duration={duration}
            setDuration={setDuration}
            startTimer={startTimer}
            pauseTimer={pauseTimer}
            resetTimer={resetTimer}
            isRunning={isRunning}
          />
          <div className="flex justify-between items-center">
            <SettingsComponent soundEnabled={soundEnabled} setSoundEnabled={setSoundEnabled} />
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm">
                  <Settings className="h-4 w-4 mr-2" />
                    Settings
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-[200px]">
                <DropdownMenuItem>
                  <div className="flex items-center space-x-2">
                    <span>Notification Sound</span>
                    <Switch checked={soundEnabled} onCheckedChange={setSoundEnabled} />
                  </div>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
