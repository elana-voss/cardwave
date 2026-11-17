// What the desktop window tests ask the screen itself, beside WebDriver: a window's frame and its screen's work
// area, the cursor, whether a window is on top and lets clicks through, and the user's Downloads folder. Windows
// asks through PowerShell and user32; Linux through X11's xdotool and xprop (the tests run there under Xvfb).
//
// Traps (Linux): X11 tells whether a window lets clicks through only by where a click lands, so `windowStyle`
// moves the cursor into the window's top left corner (away from a figure standing on its floor) and asks which
// window is under it, then puts it back at the screen's top left corner, where `away` keeps it; without a window
// manager there is no _NET_WORKAREA, and the work area is the whole screen.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { WINDOWS, type Desktop } from "./driver.ts";

function run(command: string, args: string[], what: string): string {
  const asked = spawnSync(command, args, { encoding: "utf8" });
  assert.equal(asked.status, 0, `${what}: ${asked.stderr}`);
  return asked.stdout.trim();
}

function powershell(script: string, what: string): string {
  return run("powershell", ["-NoProfile", "-Command", script], what);
}

/** The visible X11 windows of exactly this title, by xdotool. */
export function xWindows(title: string): string[] {
  const found = spawnSync("xdotool", ["search", "--onlyvisible", "--name", `^${title}$`], { encoding: "utf8" });
  return found.stdout.trim().split("\n").filter(Boolean);
}

/** The X11 window of exactly this title, by xdotool. */
function xWindow(title: string): string {
  const found = run("xdotool", ["search", "--onlyvisible", "--name", `^${title}$`], `no window “${title}”`);
  return found.split("\n")[0]!;
}

/** Whether X window `id` takes a click where the cursor is: the window under it is `id` or the frame the window
 * manager put it in (Openbox's, which xdotool names instead). */
function underCursor(id: string): boolean {
  const under = shellValues(run("xdotool", ["getmouselocation", "--shell"], "no cursor")).WINDOW;
  const parent = /Parent window id: (0x[0-9a-f]+)/.exec(run("xwininfo", ["-tree", "-id", id], "no window tree"))?.[1];
  return under === Number(id) || (parent !== undefined && under === Number(parent));
}

/** `xdotool … --shell`'s lines `NAME=value` as numbers. */
function shellValues(text: string): Record<string, number> {
  return Object.fromEntries(text.split("\n").map((line) => line.split("=")).map(([name, value]) => [name, Number(value)]));
}

/** The user's Downloads folder as the system names it (Linux: the one the app was told, by user-dirs.dirs). */
export function downloadsFolder(app: Desktop): string {
  if (!WINDOWS) return app.downloads;
  return powershell("(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path", "no Downloads folder");
}

/** The visible frame of the window of this title, and the work area of its screen, in the screen's pixels: left, top, right, bottom. */
export function placed(title: string): { frame: number[]; area: number[] } {
  if (!WINDOWS) {
    const at = shellValues(run("xdotool", ["getwindowgeometry", "--shell", xWindow(title)], "no geometry"));
    const frame = [at.X!, at.Y!, at.X! + at.WIDTH!, at.Y! + at.HEIGHT!];
    const work = spawnSync("xprop", ["-root", "_NET_WORKAREA"], { encoding: "utf8" }).stdout ?? "";
    const numbers = work.includes("=") ? work.split("=")[1]!.split(",").slice(0, 4).map(Number) : null;
    if (numbers) return { frame, area: [numbers[0]!, numbers[1]!, numbers[0]! + numbers[2]!, numbers[1]! + numbers[3]!] };
    const [width, height] = run("xdotool", ["getdisplaygeometry"], "no screen").split(" ").map(Number);
    return { frame, area: [0, 0, width!, height!] };
  }
  const script = `
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string t); [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(System.IntPtr h, int a, int[] r, int s);'
[void][W.U]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms
$h = [W.U]::FindWindow([NullString]::Value, '${title}')
if ($h -eq [System.IntPtr]::Zero) { exit 3 }
$r = New-Object int[] 4
[void][W.U]::DwmGetWindowAttribute($h, 9, $r, 16)
$a = [System.Windows.Forms.Screen]::FromHandle($h).WorkingArea
"$($r -join ' ') $($a.Left) $($a.Top) $($a.Right) $($a.Bottom)"`;
  const numbers = powershell(script, `no window “${title}”`).split(/\s+/).map(Number);
  return { frame: numbers.slice(0, 4), area: numbers.slice(4) };
}

/** Puts the screen's cursor at `x`, `y` and answers where it was. */
export function cursorAt(x: number, y: number): { x: number; y: number } {
  if (!WINDOWS) {
    const was = shellValues(run("xdotool", ["getmouselocation", "--shell"], "no cursor"));
    run("xdotool", ["mousemove", String(x), String(y)], "the cursor was not moved");
    return { x: was.X!, y: was.Y! };
  }
  const script = `Add-Type -AssemblyName System.Windows.Forms; $p = [System.Windows.Forms.Cursor]::Position; [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(${x}, ${y}); "$($p.X) $($p.Y)"`;
  const [was, wasY] = powershell(script, "the cursor was not moved").split(" ").map(Number);
  return { x: was!, y: wasY! };
}

/** Linux: puts the screen's cursor at `x`, `y` of the window of this title (its own pixels), coming from the
 * screen's corner so the app looks again, and answers whether the window then takes a click there. Windows, where
 * WebDriver's presses go past the screen: true. */
export async function cursorOnWindow(title: string, x: number, y: number): Promise<boolean> {
  if (WINDOWS) return true;
  const id = xWindow(title);
  const at = shellValues(run("xdotool", ["getwindowgeometry", "--shell", id], "no geometry"));
  const pause = () => new Promise((done) => setTimeout(done, 150));
  run("xdotool", ["mousemove", "0", "0"], "the cursor was not moved");
  await pause();
  run("xdotool", ["mousemove", String(Math.round(at.X! + x)), String(Math.round(at.Y! + y))], "the cursor was not moved");
  await pause();
  return underCursor(id);
}

/** Whether the window of this title is on top of the others, and lets clicks through (Linux: see the head). */
export function windowStyle(title: string): { top: boolean; through: boolean } {
  if (!WINDOWS) {
    const id = xWindow(title);
    const top = run("xprop", ["-id", id, "_NET_WM_STATE"], "no window state").includes("_NET_WM_STATE_ABOVE");
    const at = shellValues(run("xdotool", ["getwindowgeometry", "--shell", id], "no geometry"));
    run("xdotool", ["mousemove", String(at.X! + 2), String(at.Y! + 2)], "the cursor was not moved");
    const takes = underCursor(id);
    run("xdotool", ["mousemove", "0", "0"], "the cursor was not moved");
    return { top, through: !takes };
  }
  const script = `
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string t); [DllImport("user32.dll")] public static extern System.IntPtr GetWindowLongPtr(System.IntPtr h, int i);'
$h = [W.U]::FindWindow([NullString]::Value, '${title}')
if ($h -eq [System.IntPtr]::Zero) { exit 3 }
[W.U]::GetWindowLongPtr($h, -20).ToInt64()`;
  const style = Number(powershell(script, `no window “${title}”`));
  return { top: (style & 0x8) !== 0, through: (style & 0x20) !== 0 };
}
