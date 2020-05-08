See [unflac](https://git.sr.ht/~ft/unflac) as a better replacement of this project.

split2flac
==========

**split2flac** splits one big APE/FLAC/TTA/WV/WAV audio image (or a collection of such files, recursively) with CUE sheet
into FLAC/M4A/MP3/OGG_VORBIS/OPUS/WAV tracks with tagging, renaming, charset conversion of cue sheet, album cover images.
It also uses configuration file, so no need to pass a lot of arguments every time, only an input file.
Should work in any POSIX-compliant shell.

**NOTE**: script is able to find cover image and cue sheet **automatically** (including internal ones).

Manual installation
-------------------

  * place ``split2flac`` somewhere (``/usr/bin`` or ``/usr/local/bin`` is fine)
  * create symbolic links to the same file like this:

        cd /usr/bin    # this is a directory where split2flac was installed
        ln -s split2flac split2mp3
        ln -s split2flac split2ogg
        ln -s split2flac split2opus
        ln -s split2flac split2m4a
        ln -s split2flac split2wav

Dependencies
------------

  * Required:
    * **shntool**
    * **cuetools**

  * Optional:
    * **flac** (or better **flake**, which is much faster) to split from/into FLAC
    * **faac** and **libmp4v2** to split into M4A
    * **wavpack** to split WV
    * **mac** to split APE
    * **ttaenc** to split TTA
    * **imagemagick** to convert/resize album cover images
    * **iconv** to convert CUE sheet from non-UTF8 charset
    * **enca** to automatically detect charset if it's not UTF8
    * **lame** and **id3lib** (or better **mutagen** for Unicode tags) to split into MP3
    * **vorbis-tools** to split into OGG VORBIS
    * **opus-tools** to split into OPUS

  * Replay Gain:
    * **flac** for FLAC Replay Gain support
    * **aacgain** to adjust gain in M4A
    * **mp3gain** for MP3
    * **vorbisgain** for OGG VORBIS gain adjustment

Support
-------

Learn about Plan 9 (http://9p.io/wiki/plan9/Overview/index.html). It's awesome.
Thank you.
