
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

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} antialiased`}>
        {children}
         <Toaster />
      </body>
    </html>
  );
}
