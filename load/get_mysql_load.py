import datetime
import fcntl
import json
import multiprocessing
import os
import subprocess
import sys

import requests

this_dir = os.path.dirname(os.path.realpath(__file__))
html_dir = '/homes/muffato/public_html/load/'
save_dir = html_dir + 'data/'
backup_dir = "/nfs/production/panda/ensembl/compara/muffato/archives/mysql_stats/"


with open(os.path.join(html_dir, 'server_list.json')) as f:
    servers = json.load(f)


def get_stats(url):
    print("calling", url)
    r = requests.get(url, headers={"Content-Type" : "application/json"}, timeout=120)
    print("->", r)

    if not r.ok:
        r.raise_for_status()

    decoded = r.json()
    return decoded

def protect_do(server):
    print(server, "locking")
    lfh = open(save_dir + server + '.lock', 'w')
    # Acquire the lock
    try:
        fcntl.flock(lfh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        # Another process is already getting stats for this server, so bail out
        lfh.close()
        return

    try:
        # Execute the function
        do(server)
    except Exception as e:
        print(server, type(e), e, file=sys.stderr)

    # Release the lock no matter what
    fcntl.flock(lfh.fileno(), fcntl.LOCK_UN)
    lfh.close()
    print(server, "unlocked")

def do(server):
    print(server, "do")

    # No try-except here because I don't feel the need
    url = "https://production-services.ensembl.org/api/production/db/hosts/" + server
    st = get_stats(url)
    # Sample output:
    #{'dir': '/instances', 'disk_available_g': 1788, 'disk_total_g': 4524, 'disk_used_g': 2507, 'disk_used_pct': 55.4, 'host': 'mysql-ens-compara-prod-1', 'load_15m': 0.0, 'load_1m': 0.0, 'load_5m': 0.0, 'memory_available_m': 267, 'memory_total_m': 32106, 'memory_used_m': 31838, 'memory_used_pct': 99.2, 'n_cpus': 8}

    try:
        proc = subprocess.run([f'/homes/muffato/workspace/mysql-cmds/bin/{server}-ensadmin', '-Ne', 'SHOW PROCESSLIST'], capture_output=True, check=True)
        nproc = proc.stdout.count(b'\n')
    except subprocess.CalledProcessError as e:
        print(server, e, file=sys.stderr)
        nproc = "null"

    now = datetime.datetime.now().isoformat(' ', 'seconds')

    line = "\t".join([now, str(nproc), str(st['load_1m']), str(st['load_5m']), str(st['load_15m'])])
    print(server, line)

    # Append to backup file
    with open(backup_dir + server, 'a') as fh:
        print(line, file=fh)

    if os.path.isfile(save_dir + server) and os.stat(save_dir + server).st_size > 500000:
        # Truncate the main file if too big
        with open(save_dir + server, 'r') as fh:
            lines = fh.readlines()
            print(server, lines)
            lines = lines[-1:]
            print(server, lines)
        lines.append(line+"\n")
        with open(save_dir + server, 'w') as fh:
            fh.writelines(lines)
    else:
        # Otherwise append to it
        with open(save_dir + server, 'a') as fh:
            print(line, file=fh)

    print(server, "DONE")

# servers = servers[:3]
# multiprocessing.Pool(multiprocessing.cpu_count()).map(protect_do, servers)
multiprocessing.Pool(multiprocessing.cpu_count()).map(protect_do, servers)
# for s in servers:
    # do(s)
    # protect_do(s)
