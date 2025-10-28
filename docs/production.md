# Production

## Database Migrations

## CI/CD

Once the service is running, here are some ways to keep taps on the instance.

## Going into the container

You can execute this command to open a shell session inside of the container:
```sh
sudo podman exec -it systemd-max /bin/sh
```

## Checking Used Disk Space

Since we are storing media files on the server directly (instead of using a S3),
it is a good idea to occasionally check the disk usage.

It is also noteworthy to mention that we store the original file and the HLS conversion
on the server so a 4GB file will take up ~8GB of storage. Each additional quality conversion
(f.e. 1080p, 720p) would take up another couple of GB.

```sh
# Overall % of the disk used
$ sudo df -h /srv/max/*
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /

# Also shows mounted volumes
$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0 76.3G  0 disk
├─sda1    8:1    0   76G  0 part /var/lib/containers/storage/overlay
│                                /
├─sda14   8:14   0    1M  0 part
└─sda15   8:15   0  256M  0 part /boot/efi
sdb       8:16   0  100G  0 disk /mnt/max-movies-1
                                 /mnt/HC_Volume_103719296
sr0      11:0    1 1024M  0 rom
```

```sh
# Size of the individual storage files
$ sudo du --max-depth=1 -h /srv/max/storage
5.8G    /srv/max/storage/movie_2
15G     /srv/max/storage/media_stream_3
16G     /srv/max/storage/media_stream_1
3.1G    /srv/max/storage/movie_4
16G     /srv/max/storage/media_stream_2
6.4G    /srv/max/storage/movie_3
6.3G    /srv/max/storage/movie_1
68G     /srv/max/storage
```

## Systemd Service Logs

```sh
sudo journalctl -u max -f

sudo journalctl -u max --grep '500 POST'

sudo journalctl -u max --since today

sudo journalctl -u max --since yesterday

sudo journalctl -u max --since "2 hours ago"

sudo journalctl -u max --since "2025-10-10 14:00:00" --until "2025-10-10 16:00:00"
```

## Resource Usage

This should not become an issue, but nevertheless you can check CPU and Memory consumption with a simple `htop`.

The media converter that is working in the background only processes 1 file at a time, so CPU usage has not become
an issue yet.

```sh
htop
```

## Known Issues

During the development and my own usage of this application, I have run into some issues, especially while maintaining
it on a server. Since we should not repeat history in these cases, they will be documented, ideally with their solution.

### Issue #1: `Failed to attach to cgroup`

After running this service for weeks on end without any issues, one day I pushed an update, pulled the latest image directly on the server and restarted the systemd service. This was the output:
```sh
$ sudo systemctl status max.service
× max.service - Self hosted media application
     Loaded: loaded (/etc/containers/systemd/max.container; generated)
     Active: failed (Result: exit-code) since Sat 2025-10-25 12:49:51 UTC; 6s ago
   Duration: 8h 42min 19.964s
    Process: 370935 ExecStart=/usr/bin/podman run --name=systemd-max --cidfile=/run/max.cid --replace --rm --cgroups=split --sdnotify=conmon -d -v /s>
    Process: 370936 ExecStopPost=/usr/bin/podman rm -v -f -i --cidfile=/run/max.cid (code=exited, status=0/SUCCESS)
   Main PID: 370935 (code=exited, status=219/CGROUP)
        CPU: 24ms

Oct 25 12:49:51 max systemd[1]: Starting max.service - Self hosted media application...
Oct 25 12:49:51 max systemd[1]: max.service: Main process exited, code=exited, status=219/CGROUP
Oct 25 12:49:51 max systemd[1]: max.service: Failed with result 'exit-code'.
Oct 25 12:49:51 max systemd[1]: Failed to start max.service - Self hosted media application.
```

Which is also indicated when getting the status of a running service:
```sh
● max.service - Self hosted media application
     Loaded: loaded (/etc/containers/systemd/max.container; generated)
     Active: active (running) since Sat 2025-10-25 19:23:45 UTC; 52min ago
   Main PID: 6895 (conmon)
      Tasks: 22 (limit: 9253)
     Memory: 126.9M (peak: 134.0M)
        CPU: 53.488s
     CGroup: /system.slice/max.service
             └─runtime
               └─runtime
                 └─runtime
                   └─runtime
                     └─runtime
                       └─runtime
                         └─runtime
                           └─runtime
                             └─runtime
                               └─runtime
                                 └─runtime
                                   ...
```

After investigation I found this:
```sh
$ sudo journalctl -b -p err | grep -i cgroup
Oct 25 11:38:15 max (podman)[367640]: max.service: Failed to attach to cgroup /system.slice/max.service: Device or resource busy
```

An issue was filed, but I resolved it before anyone took a look at it: [https://github.com/containers/podman/issues/27369](https://github.com/containers/podman/issues/27369)

The solution was that I forgot to make `healthcheck.sh` executable so it was failing and restarting the service. Simple `chmod +x` fixed it!
