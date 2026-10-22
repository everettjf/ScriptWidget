export type DataAPIValue = null | boolean | number | string | DataAPIValue[] | { [key: string]: DataAPIValue };
export interface DataAPI {
  id: string;
  group: "device" | "system" | "health" | "location" | "calendar";
  value: DataAPIValue;
  legacy?: string[];
  platforms: ("ios" | "macos")[];
  authorization: "none" | "healthRead" | "locationWhenInUse" | "calendarRead";
  notes: string;
  arguments: string[];
  asynchronous: boolean;
  minimumRuntimeVersion: string;
  nativeSource: string;
  operation: "authorization" | "availability" | "read";
  mock: "editable";
}
export const dataAPICatalog: DataAPI[];
