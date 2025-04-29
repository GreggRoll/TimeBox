import type {Metadata} from 'next';
import {Inter} from 'next/font/google';
import './globals.css';
import { Toaster } from "@/components/ui/toaster"

const inter = Inter({
  variable: '--font-inter',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: 'TimeWise',
  description: 'A web based app for time boxing',
};

import { ThemeProvider } from '@/components/theme-provider';
import React from 'react';

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} antialiased`}>
         <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
        {children}
         <Toaster />
         </ThemeProvider>
      </body>
    </html>
  );
}
