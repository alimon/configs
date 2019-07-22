#!/usr/bin/python
import pexpect

child = pexpect.spawn('./run_fedora_iot.sh', timeout=120)

child.logfile = open("/dev/tty", "w")
def init_login():
    child.expect(".*Please make a selection from the above.", timeout=120)
    child.sendline("2")

    child.expect(".*Create user")
    child.expect("]:")
    child.sendline("1")

    child.expect(".*User name")
    child.expect("]:")
    child.sendline("3")

    child.expect("and press ENTER:")
    child.sendline("ledge")

    child.expect("]:")
    child.sendline("4")

    child.expect("]:")
    child.sendline("5")
    child.expect("Password:")
    child.sendline("ledge2019")
    child.expect("Password \(confirm\):")
    child.sendline("ledge2019")

    child.expect("]:")
    child.sendline("6")

    child.expect("]:")
    child.sendline("c")

    child.expect("]:")
    child.sendline("q")

    child.expect("Please respond")
    child.expect(":")
    child.sendline("yes")

def login():
    child.expect("localhost login:")
    child.send("ledge\n")

    child.expect("Password:")
    child.send("ledge2019\n")
    child.expect("ledge.*$")
    child.send("sudo su\n")
    child.expect("password for ledge:")
    child.send("ledge2019\n")
    child.expect("ledge.*$")

def grub_serial():
    child.sendline("""echo -e GRUB_TERMINAL=\\\"serial\\\" >> /etc/default/grub""")
    child.expect("ledge.*$")

    child.sendline("""echo -e GRUB_SERIAL_COMMAND=\\\"serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1\\\" >> /etc/default/grub""")
    child.expect("ledge.*$")

    child.sendline('cat /etc/default/grub\n')
    child.expect("ledge.*$")
    child.send("grub2-mkconfig -o /boot/grub2/grub.cfg\n")
    child.expect("ledge.*$")

def power_off():
    child.send("poweroff\n")

init_login()
login()
grub_serial()
power_off()

child.expect(pexpect.EOF)
