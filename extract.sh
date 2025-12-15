#!/usr/bin/env bash
# extract.sh — smart extractor that uses `file(1)` not the filename
# Usage:  ./extract.sh <archive-or-compressed-file>

set -euo pipefail
shopt -s nocasematch        # pattern-matching in case/esac is case-insensitive

usage() { printf 'Usage: %s <file>\n' "${0##*/}"; exit 1; }
[[ $# -eq 1 ]] || usage
[[ -f $1 ]]   || { echo "Error: '$1' is not a regular file"; exit 1; }

FILE=$1
DESC=$(file -b "$FILE")                 # full textual description
MIME=$(file -b --mime-type "$FILE")     # e.g. application/x-gzip

# Helper: if the compressed payload is a tar archive, unpack it straight away
decompress_or_pipe_to_tar() {
    local cmd=$1            # gunzip / bunzip2 / xz / zstd / lzip / lzma …
    if [[ $DESC == *"tar archive"* ]]; then
        # -c  -> write to stdout     -d -> decompress
        "$cmd" -cd "$FILE" | tar -xf -
    else
        "$cmd" -d  "$FILE"
    fi
}

case "$MIME" in
    ##################################################################
    # ── plain (uncompressed) archives ───────────────────────────────
    ##################################################################
    application/x-tar)                       tar    -xf   "$FILE"                        ;;
    application/zip)                         unzip        "$FILE"                        ;;
    application/x-7z-compressed)             7z     x     "$FILE"                        ;;
    application/x-rar | application/vnd.rar) unrar  x     "$FILE"                        ;;

    ##################################################################
    # ── single-file compressors ─────────────────────────────────────
    #     let the helper decide whether to pipe into tar(1)
    ##################################################################
    application/x-gzip | application/gzip)   decompress_or_pipe_to_tar gunzip            ;;
    application/x-bzip2)                     decompress_or_pipe_to_tar bunzip2           ;;
    application/x-xz)                        decompress_or_pipe_to_tar xz                ;;
    application/x-zstd)                      decompress_or_pipe_to_tar zstd              ;;
    application/x-lzip)                      decompress_or_pipe_to_tar lzip              ;;
    application/x-lzma)                      decompress_or_pipe_to_tar lzma              ;;
    application/x-lzop)                      decompress_or_pipe_to_tar lzop              ;;
    application/x-lz4)                       decompress_or_pipe_to_tar lz4               ;;

    ##################################################################
    # ── fall-back — try the plain description before giving up ──────
    ##################################################################
    *)
        case "$DESC" in
            *"gzip compressed data"*)        decompress_or_pipe_to_tar gunzip            ;;
            *"bzip2 compressed data"*)       decompress_or_pipe_to_tar bunzip2           ;;
            *"XZ compressed data"*)          decompress_or_pipe_to_tar xz                ;;
            *"Zip archive data"*)            unzip        "$FILE"                        ;;
            *"7-zip archive data"*)          7z x         "$FILE"                        ;;
            *"RAR archive data"*)            unrar x      "$FILE"                        ;;
            *"POSIX tar archive"*)           tar -xf      "$FILE"                        ;;
            *)
                echo "extract.sh: unsupported file type:"
                echo "  mime: $MIME"
                echo "  desc: $DESC"
                exit 1
                ;;
        esac
        ;;
esac

