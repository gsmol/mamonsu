# -*- coding: utf-8 -*-

import subprocess
import time
import logging
import os
import re


class Shell(object):

    # exit status of timeout code
    TimeoutCode = -1

    def __init__(self, cmd, wait_time=10):
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


class SystemInfo(object):

    """ Shell """
    def __init__(self):
        self.sysctl = self._fetch_sysctl()
        self.dmesg = self._fetch_dmesg()
        self.lspci = self._fetch_lspci()
        self.system_release = self._fetch_release()
        self.kernel = self._fetch_kernel()
        self.virtualization = self._fetch_virtualization(self.dmesg)
        self.raid = self._fetch_raid(self.lspci)

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
            logging.error(
                "`sysctl -a` error code: %s", shell.status)
        return result

    def _fetch_dmesg(self):
        try:
            with open('/var/log/dmesg', 'r') as content_file:
                content = content_file.read()
                return content
        except Exception as e:
            logging.error("Fetch dmesg error: %s", e)
            return ''

    def _fetch_virtualization(self, dmesg):
        if dmesg == '':
            return ''
        if re.search('vmware', dmesg, re.IGNORECASE):
            return 'VMWare'
        if re.search('vmxnet', dmesg, re.IGNORECASE):
            return 'VMWare'
        if re.search('paravirtualized kernel on vmi', dmesg, re.IGNORECASE):
            return 'VMWare'
        if re.search('Xen virtual console', dmesg, re.IGNORECASE):
            return 'Xen'
        if re.search('paravirtualized kernel on xen', dmesg, re.IGNORECASE):
            return 'Xen'
        if re.search('qemu', dmesg, re.IGNORECASE):
            return 'QEmu'
        if re.search('paravirtualized kernel on KVM', dmesg, re.IGNORECASE):
            return 'KVM'
        if re.search('VBOX', dmesg, re.IGNORECASE):
            return 'VirtualBox'
        if re.search('hd.: Virtual .., ATA.*drive', dmesg, re.IGNORECASE):
            return 'Microsoft VirtualPC'
        return ''

    def _fetch_lspci(self):
        shell = Shell('lspci')
        if shell.status == 0:
            return shell.stdout
        else:
            logging.error("lspci error code: %s", shell.status)
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
                        if not re.search('DISTRIB_DESCRIPTION', line):
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
            logging.error("`uname -r` error code: %s", shell.status)
            return ''

    def _fetch_raid(sel, lspci):
        if lspci != '':
            if re.search(
                'RAID bus controller: LSI Logic / Symbios Logic MegaRAID SAS',
                    lspci, re.IGNORECASE):
                return 'LSI Logic MegaRAID SAS'
            if re.search(
                'RAID bus controller: LSI Logic / Symbios Logic LSI MegaSAS',
                    lspci, re.IGNORECASE):
                return 'LSI Logic MegaRAID SAS'
            if re.search(
                'Fusion-MPT SAS',
                    lspci, re.IGNORECASE):
                return 'Fusion-MPT SAS'
            if re.search(
                'RAID bus controller: LSI Logic / Symbios Logic Unknown',
                    lspci, re.IGNORECASE):
                return 'LSI Logic Unknown'
            if re.search(
                'RAID bus controller: Adaptec AAC-RAID',
                    lspci, re.IGNORECASE):
                return 'AACRAID'
            if re.search(
                '3ware [0-9]* Storage Controller',
                    lspci, re.IGNORECASE):
                return '3Ware'
            if re.search(
                'Hewlett-Packard Company Smart Array',
                    lspci, re.IGNORECASE):
                return 'HP Smart Array'
            if re.search(
                'Hewlett-Packard Company Smart Array',
                    lspci, re.IGNORECASE):
                return 'HP Smart Array'
        return ''
