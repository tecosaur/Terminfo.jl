# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    ttyhastruecolor()

Return a boolean signifying whether the current terminal supports 24-bit colors.

Multiple conditions are taken as signifying truecolor support, specifically any of the following:
- The `COLORTERM` environment variable is set to `"truecolor"` or `"24bit"`
- The current terminfo sets the [`RGB`[^1]
  capability](https://invisible-island.net/ncurses/man/user_caps.5.html#h3-Recognized-Capabilities)
  (or the legacy `Tc` capability[^2]) flag
- The current terminfo provides `setrgbf` and `setrgbb` strings[^3]
- The current terminfo has a `colors` number greater that `256`, on a unix system
- The VTE version is at least 3600 (detected via the `VTE_VERSION` environment variable)
- The current terminal has the `XTERM_VERSION` environment variable set
- The current terminal appears to be iTerm according to the `TERMINAL_PROGRAM` environment variable
- The `TERM` environment variable corresponds to: linuxvt, rxvt, or st

[^1]: Added to Ncurses 6.1, and used in `TERM=*-direct` terminfos.
[^2]: Convention [added to tmux in 2016](https://github.com/tmux/tmux/commit/427b8204268af5548d09b830e101c59daa095df9),
      superseded by `RGB`.
[^3]: Proposed by [Rüdiger Sonderfeld in 2013](https://lists.gnu.org/archive/html/bug-ncurses/2013-10/msg00007.html),
      adopted by a few terminal emulators.

!!! note
    The set of conditions is messy, because the situation is a mess, and there's
    no resolution in sight. `COLORTERM` is widely accepted, but an imperfect
    solution because only `TERM` is passed across `ssh` sessions. Terminfo is
    the obvious place for a terminal to declare capabilities, but it's taken
    enough years for ncurses/terminfo to declare a standard capability (`RGB`)
    that a number of other approaches have taken root. Furthermore, the official
    `RGB` capability is *incompatible* with 256-color operation, and so is
    unable to resolve the fragmentation in the terminal ecosystem.
"""
function ttyhastruecolor()
    # Lasciate ogne speranza, voi ch'intrate
    get(ENV, "COLORTERM", "") ∈ ("truecolor", "24bit") ||
        get(current_terminfo, :RGB, false) || get(current_terminfo, :Tc, false) ||
        (haskey(current_terminfo, :setrgbf) && haskey(current_terminfo, :setrgbb)) ||
        @static if Sys.isunix() get(current_terminfo, :colors, 0) > 256 else false end ||
        (Sys.iswindows() && Sys.windows_version() ≥ v"10.0.14931") || # See <https://devblogs.microsoft.com/commandline/24-bit-color-in-the-windows-console/>
        something(tryparse(Int, get(ENV, "VTE_VERSION", "")), 0) >= 3600 || # Per GNOME bug #685759 <https://bugzilla.gnome.org/show_bug.cgi?id=685759>
        haskey(ENV, "XTERM_VERSION") ||
        get(ENV, "TERMINAL_PROGRAM", "") == "iTerm.app" || # Why does Apple need to be special?
        haskey(ENV, "KONSOLE_PROFILE_NAME") || # Per commentary in VT102Emulation.cpp
        haskey(ENV, "KONSOLE_DBUS_SESSION") ||
        let term = get(ENV, "TERM", "")
            startswith(term, "linux") || # Linux 4.8+ supports true-colour SGR.
                startswith(term, "rxvt") || # See <http://lists.schmorp.de/pipermail/rxvt-unicode/2016q2/002261.html>
                startswith(term, "st") # From experimentation
        end
end
