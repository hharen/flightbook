# README

## Local
### Server
- start server `bin/rails`
- start console `rails c`

## SERVER
- `ssh root@challengic.hharen.com`

### Update regularly
- `apt update` - downloads the newest list of updates
- `apt upgrade` - does the actual upgrade
- `reboot` - reboots the server

### Find volumes
- `docker volume ls`

## Kamal
- `kamal redeploy`
- `kamal app stop`
- `kamal app start`
- `kamal app exec --reuse -i 'bin/rails c'` or `kamal app exec --reuse 'bin/rails runner "CLASS.update_all(ATRIBUTE: VALUE)"'`

### Logs
- `kamal app logs` - View recent logs
- `kamal app logs --follow` - Follow logs in real-time
- `kamal app logs --since 1h` - View logs from a specific time
- `kamal app logs --timestamps` - View logs with timestamps
- `kamal app logs --all` - View logs from all containers
- `kamal app logs --service web` - View logs for a specific service
- `kamal proxy logs -f` - Real time logs from Kamal's proxy

