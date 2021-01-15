# rem disable win update
Net stop wuauserv
Net stop bits
Net stop Dosvc
# rem disable windows search
net.exe stop "Windows search"
