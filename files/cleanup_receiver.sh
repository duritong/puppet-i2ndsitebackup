#!/bin/bash

for folder in $(ls -1 /srv/backup | grep -Ev '_(archive|encfs)$'); do
  if [ ! -z "${folder}" ] && [ -d /srv/backup/${folder} ]; then
    find /srv/backup/${folder} -mtime +1100 -type f -delete
    find /srv/backup/${folder} -type d -empty -delete
  fi
done
