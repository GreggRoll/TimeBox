'use client';

import React, {useState} from 'react';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';

export default function Home() {
  const [date, setDate] = useState('');
  const [topPriorities, setTopPriorities] = useState(['', '', '']);
  const [brainDump, setBrainDump] = useState('');
  const timeSlots = Array.from({length: 19}, (_, i) => i + 5); // Times from 5 to 23

  return (
    <div className="timebox-container">
      <div className="timebox-left">
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
            className="h-10 w-10 mr-2">
            <rect width="18" height="18" x="3" y="3" rx="2" ry="2" />
            <line x1="9" x2="15" y1="3" y2="21" />
          </svg>
          <h1 className="text-2xl font-bold">The Time Box.</h1>
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
    </div>
  );
}
