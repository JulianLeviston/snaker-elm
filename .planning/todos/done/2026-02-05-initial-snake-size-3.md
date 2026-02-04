---
created: 2026-02-05T10:30
title: Set initial snake size to 3 segments
area: general
files: []
---

## Problem

Snakes currently start with only a head (1 segment). The initial size should be 3 segments (head + 2 body segments) to make the game feel more substantial from the start.

## Solution

Find snake initialization code in Elm and change starting body to include 2 additional segments behind the head.
