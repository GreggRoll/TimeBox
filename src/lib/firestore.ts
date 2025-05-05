import { doc, setDoc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface TimeboxData {
  topPriorities: string[];
  brainDump: string;
  timeSlotTasks: { [time: number]: { '00'?: string; '30'?: string } };
}

// Ensure date is formatted as 'yyyy-MM-dd' before calling
export async function saveTimeboxData(userId: string, date: string, data: Partial<TimeboxData>) {
  if (!userId || !date) {
    console.error("User ID and date are required to save timebox data.");
    return;
  }
  const timeboxId = `${userId}_${date}`;
  const timeboxRef = doc(db, "timeboxes", timeboxId);
  try {
    // Use merge: true to update fields without overwriting the entire document
    await setDoc(timeboxRef, data, { merge: true });
    console.log("Timebox data saved for:", timeboxId);
  } catch (error) {
    console.error("Error saving timebox data:", error);
  }
}

// Ensure date is formatted as 'yyyy-MM-dd' before calling
export async function getTimeboxData(userId: string, date: string): Promise<TimeboxData | null> {
 if (!userId || !date) {
    console.error("User ID and date are required to get timebox data.");
    return null;
  }
  const timeboxId = `${userId}_${date}`;
  const timeboxRef = doc(db, "timeboxes", timeboxId);
  try {
    const docSnap = await getDoc(timeboxRef);
    if (docSnap.exists()) {
       console.log("Timebox data retrieved for:", timeboxId);
      return docSnap.data() as TimeboxData;
    } else {
      console.log("No timebox document found for:", timeboxId);
      // Return default structure if no document exists
      return { topPriorities: ['', '', ''], brainDump: '', timeSlotTasks: {} };
    }
  } catch (error) {
    console.error("Error getting timebox data:", error);
    return null;
  }
}
