#!/bin/bash
rm /tmp/nvimsocket
neovide -- --listen /tmp/nvimsocket -S /home/artin/Vshrd/config/nvim/session.vim
