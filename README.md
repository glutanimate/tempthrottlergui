tempthrottlergui
================

GUI frontend for sepero's temp-throttle

     based on temp-throttle (http://github.com/Sepero/temp-throttle/) 
     original script by Sepero 2013 (sepero 111 @ gmail . com)

     getXuser found in acpi scripts
     preamble largely based on yad notification example

     NAME:         tempthrottlergui.sh
     VERSION:      0.1
     AUTHOR:       (c) 2013 Glutanimate
     DESCRIPTION:  simple GUI frontend for temp-throttle
     FEATURES:     - GUI selection of temperature limit
                   - systray indicator with information on current throttle/unthrottle
                     (hover to show as a tooltip)
                   - original frequency is restored on exit

     DEPENDENCIES: yad libnotify-bin
                   (yad is an advanced Zenity fork (https://code.google.com/p/yad/). It has yet to be
                    packaged in the official Ubuntu repos but can be installed from the following 
                    webupd8 PPA: y-ppa-manager)

     LICENSE:      GNU GPL 2.0

     NOTICE:       THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
                   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
                   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
                   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
                   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
                   OR OTHER DEALINGS IN THE SOFTWARE.


     WARNING:      This script is probably kind of crude in some parts.
     USAGE:        1.) The script has to be executed with root privileges. `gksudo` will not work.
                       (CLI: `sudo tempthrottlergui.sh`, GUI: `pkexec --user root tempthrottlergui.sh` or
                        `sh -c "pkexec --user root tempthrottlergui.sh"`)
                   2.) Select the desired temperature limit and hit OK
                   3.) the temp-throttle code should now do its magic. You can check the current status
                       of the script by hovering over the systray indicator
                   4.) you can exit the script from the right click menu of the indicator. CPU frequencies
                       will be restored.
