To fix EOL issue on a fresh CentOS:

```bash
curl https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/yum.sh | sh
```

> [!WARNING]
> There may be other processes using Yum which will cause the script to hang. In this case, cancel the script execution and kill the processes in question with `kill -9 <PID>`.