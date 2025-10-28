# Production

Once the service is running, here are some ways to keep taps on the instance.

## Going into the container

You can execute this command to open a shell session inside of the container:
```sh
sudo podman exec -it systemd-gecko /bin/sh
```

## Checking Used Disk Space

Since we are storing media files on the server directly (instead of using a S3),
it is a good idea to occasionally check the disk usage.

It is also noteworthy to mention that we store the original file and the HLS conversion
on the server so a 4GB file will take up ~8GB of storage. Each additional quality conversion
(f.e. 1080p, 720p) would take up another couple of GB.

```sh
# Overall % of the disk used
$ sudo df -h /var/lib/gecko/*
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /
/dev/sda1        75G   71G  1.5G  99% /

```sh
# Size of the individual storage files
$ sudo du --max-depth=1 -h /var/lib/gecko/storage
5.8G    /var/lib/gecko/storage/movie_2
15G     /var/lib/gecko/storage/media_stream_3
16G     /var/lib/gecko/storage/media_stream_1
3.1G    /var/lib/gecko/storage/movie_4
16G     /var/lib/gecko/storage/media_stream_2
6.4G    /var/lib/gecko/storage/movie_3
6.3G    /var/lib/gecko/storage/movie_1
68G     /var/lib/gecko/storage
```

## Systemd Service Logs

```sh
sudo journalctl -u gecko -f

sudo journalctl -u gecko --grep '500 POST'

sudo journalctl -u gecko --since today

sudo journalctl -u gecko --since yesterday

sudo journalctl -u gecko --since "2 hours ago"

sudo journalctl -u gecko --since "2025-10-10 14:00:00" --until "2025-10-10 16:00:00"
```

## Resource Usage

This should not become an issue, but nevertheless you can check CPU and Memory consumption with a simple `htop`.

The media converter that is working in the background only processes 1 file at a time, so CPU usage has not become
an issue yet.

```sh
htop
```

## Systemd Service

Output all errors from the service logs
```sh
$ sudo journalctl -b -p err
```
