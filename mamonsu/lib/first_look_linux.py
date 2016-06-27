# -*- coding: utf-8 -*-

import subprocess
import time
import logging
import os
import re


class Shell(object):

    # exit status of timeout code
    TimeoutCode = -1

    def __init__(self, cmd, wait_time=10, sudo=False):
        self.status = 0
        self.cmd = cmd
        self.stdout, self.stderr = None, None
        self.wait_time, self.exec_time = wait_time, 0
        self._run()

    def _run(self):
        p = subprocess.Popen(
            self.cmd, shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, close_fds=True)
        while p.poll() is None:
            time.sleep(0.1)
            self.exec_time += 0.1
            if self.wait_time > 0 and self.exec_time > self.wait_time:
                self.status = self.TimeoutCode
                return
        self.status = p.returncode
        self.stdout = ''.join(p.stdout.readlines())
        self.stderr = ''.join(p.stdout.readlines())

    def error(self):
        return 'Command `{0}` error code: {1}, sdterr: {2}'.format(
            self.cmd, self.status, self.stderr)


class SystemInfo(object):

    def __init__(self):
        self.sysctl = self._fetch_sysctl()
        self.dmesg = self._fetch_dmesg()
        self.lspci = self._fetch_lspci()
        self.system_release = self._fetch_release()
        self.kernel = self._fetch_kernel()
        self.virtualization = self._fetch_virtualization(self.dmesg)
        self.parsed_raid = self._parse_raid(self.lspci, self.dmesg)
        self.uptime = self._fetch_uptime()
        self.cpu_arch = self._fetch_cpu_arch()
        self.os_arch = self._fetch_os_arch()
        self.dmidecode = self._fetch_dmidecode()
        self.system_info = self._fetch_system_info()
        self.mount = self._fetch_mount()
        self.df = self._fetch_df()
        self.cpu_info = self._fetch_cpu_info()
        self.parsed_cpu_info = self._parse_cpu_info(self.cpu_info)
        self.meminfo = self._fetch_meminfo()
        self.parsed_meminfo = self._parse_meminfo(self.meminfo)

    _suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']

    def _humansize(self, nbytes):
        if nbytes == 0:
            return '0 B'
        i = 0
        while nbytes >= 1024 and i < len(self._suffixes)-1:
            nbytes /= 1024.
            i += 1
        f = ('%.2f' % nbytes).rstrip('0').rstrip('.')
        return '%s %s' % (f, self._suffixes[i])

    def _fetch_sysctl(self):
        result = {}
        shell = Shell('sysctl -a')
        if shell.status == 0:
            logging.debug("`systcl -a` return stderr: %s", shell.stderr)
            for out in shell.stdout.split("\n"):
                try:
                    k, v = out.split(" = ")
                    result[k] = out[k]
                except:
                    logging.error(
                        "unexpected `systcl -a` output: '{0}'".format(out))
                    return
        else:
            logging.error(shell.error())
        return result

    def _fetch_dmesg(self):
        try:
            if os.path.isfile('/var/log/dmesg'):
                with open('/var/log/dmesg', 'r') as content_file:
                    content = content_file.read()
                    return content
            shell = Shell('dmesg')
            if shell.status == 0:
                return shell.stdout
            else:
                raise(shell.error())
        except Exception as e:
            logging.error('Fetch dmesg error: %s', e)
            return ''

    def _fetch_virtualization(self, dmesg):
        if dmesg == '':
            return ''
        if re.search(r'vmware', dmesg, re.I):
            return 'VMWare'
        if re.search(r'vmxnet', dmesg, re.I):
            return 'VMWare'
        if re.search(r'paravirtualized kernel on vmi', dmesg, re.I):
            return 'VMWare'
        if re.search(r'Xen virtual console', dmesg, re.I):
            return 'Xen'
        if re.search(r'paravirtualized kernel on xen', dmesg, re.I):
            return 'Xen'
        if re.search(r'qemu', dmesg, re.I):
            return 'QEmu'
        if re.search(r'paravirtualized kernel on KVM', dmesg, re.I):
            return 'KVM'
        if re.search(r'VBOX', dmesg, re.I):
            return 'VirtualBox'
        if re.search(r'hd.: Virtual .., ATA.*drive', dmesg, re.I):
            return 'Microsoft VirtualPC'
        return ''

    def _fetch_lspci(self):
        shell = Shell('lspci')
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error(shell.error())
            return ''

    def _fetch_release(self):
        for file in ['/etc/fedora-release', '/etc/redhat-release',
                     '/etc/system-release']:
                if os.path.isfile(file):
                    try:
                        with open(file, 'r') as content_file:
                            content = content_file.read()
                            return content
                    except:
                        pass
        if os.path.isfile('/etc/lsb-release'):
            try:
                with open('/etc/lsb-release', 'r') as f:
                    for line in f:
                        if not re.search(r'DISTRIB_DESCRIPTION', line):
                            continue
                        _, content = line.split('=')
                        return content
            except:
                pass
        if os.path.isfile('/etc/debian_version'):
            try:
                with open('/etc/debian_version', 'r') as f:
                    content = content_file.read()
                    return 'Debian-based version {0}'.format(content)
            except:
                pass
        return 'Unknown'

    def _fetch_kernel(self):
        shell = Shell('uname -r')
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error(shell.error())
            return ''

    def _parse_raid(sel, lspci, dmesg):
        if lspci != '':
            if re.search(
                r'RAID bus controller: LSI Logic / Symbios Logic MegaRAID SAS',
                    lspci, re.I):
                return 'LSI Logic MegaRAID SAS'
            if re.search(
                r'RAID bus controller: LSI Logic / Symbios Logic LSI MegaSAS',
                    lspci, re.I):
                return 'LSI Logic MegaRAID SAS'
            if re.search(
                r'Fusion-MPT SAS',
                    lspci, re.I):
                return 'Fusion-MPT SAS'
            if re.search(
                r'RAID bus controller: LSI Logic / Symbios Logic Unknown',
                    lspci, re.I):
                return 'LSI Logic Unknown'
            if re.search(
                r'RAID bus controller: Adaptec AAC-RAID',
                    lspci, re.I):
                return 'AACRAID'
            if re.search(
                r'3ware [0-9]* Storage Controller',
                    lspci, re.I):
                return '3Ware'
            if re.search(
                r'Hewlett-Packard Company Smart Array',
                    lspci, re.I):
                return 'HP Smart Array'
            if re.search(
                r'Hewlett-Packard Company Smart Array',
                    lspci, re.I):
                return 'HP Smart Array'
        if dmesg != '':
            if re.search(r'scsi[0-9].*: .*megaraid', dmesg, re.I):
                return 'LSI Logic MegaRAID SAS'
            if re.search(r'Fusion MPT SAS', dmesg):
                return 'Fusion-MPT SAS'
            if re.search(r'scsi[0-9].*: .*aacraid', dmesg, re.I):
                return 'AACRAID'
            if re.search(
                r'scsi[0-9].*: .*3ware [0-9]* Storage Controller',
                    dmesg, re.I):
                return '3Ware'
        return ''

    def _fetch_uptime(self):
        shell = Shell('uptime')
        if not shell.status == 0:
            logging.error(shell.error())
        return shell.stdout

    def _fetch_cpu_arch(self):
        if os.path.isfile('/proc/cpuinfo'):
            try:
                with open('/proc/cpuinfo', 'r') as content_file:
                    content = content_file.read()
                    if re.search(r' lm ', content):
                        return '64-bit'
                    else:
                        return '32-bit'
            except:
                pass
        return 'N/A'

    def _fetch_os_arch(self):
        shell = Shell('getconf LONG_BIT')
        if shell.status == 0:
            if re.search('64', shell.stdout):
                return '64-bit'
            if re.search('32', shell.stdout):
                return '32-bit'
        else:
            logging.error(shell.error())
        return 'N/A'

    def _fetch_dmidecode(self):
        sudo = os.getuid() == 0
        shell = Shell('dmidecode', sudo=sudo)
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error(shell.error())
            return ''

    def _fetch_system_info(self):

        def set_key(result, key, param):
            sudo = os.getuid() == 0
            shell = Shell(
                'dmidecode -s "{1}"'.format(key), wait_time=1, sudo=sudo)
            if shell.status == 0:
                result[param] = shell.stdout
            else:
                logging.error(shell.error())

        result = {}
        set_key(result, 'vendor', 'system-manufacturer')
        set_key(result, 'product', 'system-product-name')
        set_key(result, 'chassis', 'chassis-type')
        set_key(result, 'serial', 'system-serial-number')
        return result

    def _fetch_mount(self):
        shell = Shell('mount')
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error(shell.error())
            return ''

    def _fetch_df(self):
        shell = Shell('df -h -P')
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error(shell.error())
            return ''

    def _fetch_cpu_info(self):
        if os.path.isfile('/proc/cpuinfo'):
            try:
                with open('/proc/cpuinfo', 'r') as content_file:
                    content = content_file.read()
                    return content
            except:
                logging.error('Can\'t read /proc/cpuinfo')
                return ''
        else:
            logging.error('Can\'t find /proc/cpuinfo')
        return ''

    def _parse_cpu_info(self, info):

        def remove_duplicates(values):
            output = []
            seen = set()
            for value in values:
                if value not in seen:
                    output.append(value)
                    seen.add(value)
            return output

        def fetch_first(reg, info):
            val = re.search(reg, info. re.M)
            if val is not None:
                return val.group(1)
            else:
                return 'N/A'

        if info == '':
            return {}

        result = {}
        result['virtual'] = len(
            re.findall(r'(^|\n)processor', info))
        result['physical'] = len(remove_duplicates(
            re.findall(
                r'^physical id\s+\:\s+(\d+)', info, re.M)))
        cores = re.search(
            r'^cpu cores\s+\:\s+(\d+)', info, re.M)
        if cores is not None:
            result['cores'] = int(cores.group(1))
        else:
            result['cores'] = 0
        if result['physical'] == 0:
            result['physical'] = result['virtual']
        result['hyperthreading'] = False
        if result['cores'] > 0:
            if result['cores'] < result['virtual']:
                result['hyperthreading'] = True
        result['model'] = fetch_first(r'model name\s+\:\s+(.*)$', info)
        result['cache'] = fetch_first(r'cache size\s+\:\s+(.*)$', info)
        result['speed'] = fetch_first(r'^cpu MHz\s+\:\s+(\d+\.\d+)$', info)
        return result

    def _fetch_meminfo(self):
        if os.path.isfile('/proc/meminfo'):
            try:
                with open('/proc/meminfo', 'r') as content_file:
                    content = content_file.read()
                    return content
            except:
                logging.error('Can\'t read /proc/meminfo')
                return ''
        else:
            logging.error('Can\'t find /proc/meminfo')
        return ''

    def _parse_meminfo(self, data):
        if data == '':
            return {}
        result = {}
        for info in re.findall(r'^(\S+)\:\s+(\d+)\s+kB$', data, re.M):
            result[info[0]] = int(info(1))*1024
        result['_TOTAL'] = ''
        if 'MemTotal' in result:
            result['_TOTAL'] = self._humansize(result['MemTotal'])
        result['_SWAP'] = ''
        if 'SwapTotal' in result:
            result['_TOTAL'] = self._humansize(result['SwapTotal'])
        result['_CACHED'] = ''
        if 'Cached' in result:
            result['_CACHED'] = self._humansize(result['Cached'])
        result['_DIRTY'] = ''
        if 'Dirty' in result:
            result['_DIRTY'] = self._humansize(result['Dirty'])
        return result
