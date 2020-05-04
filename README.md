# Get-Reindexing-done-the-right-way (utility for Synology DiskStation Manager)

## Introduction
For me it used to be very frustrating when photos and videos, newly uploaded to my Synology NAS,
were not available on my TV, so I decided to develop a script to index files on demand.

Full reindexing using built-in `synoindex` utility takes too much time, so lets do it the right way
and handle only difference without rescaning already indexed files.

## Requirements:
- Assumes that it's running on Synology DiskStation Manager (DSM)*, so `synoindex` utility is available.
- Requires `root` permissions since it operates both with file system and PostgreSQL database.

## Installation:
1. Put the script on the system and make it executable.
2. Add it's location to the `PATH` environment variable.
3. (Optional) add to task scheduler for regularly updating index.

## Usage
```
# ./get-reindexing-done-the-right-way.sh --help
Usage: ./get-reindexing-done-the-right-way.sh [OPTION]... [FILE]...

get-reindexing-done-the-right-way 0.1.0-alpha

Sync information about the FILEs (the current directory by default) with media files database.
Full reindexing using synoindex takes too much time, so lets do it the right way and handle
only difference, without rescaning already indexed files.

Options:
  -t, --type TYPE       video, photo or music, default: video
  -f, --force           ignore a timestamp file and check all files

  -l, --log FILE        log file location, default: /var/log/get-reindexing-done-the-right-way/log.txt
  -V, --verbose         add more details to the log
  -s, --silent          do not duplicate log messages to stdout

  -h, --help            show this help message and exit
  -v, --version         show script version and exit
  -L, --list-only       show currently indexed files and exit

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Copyright (c) 2020 Evgeny Karpovich, released under MIT license
```