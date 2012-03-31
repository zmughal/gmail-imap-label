gmail-imap-label
# Description
Proxy that sits between an IMAP client and Gmail's IMAPS server and adds GMail
labels to the X-Label header.

Tested with mutt 1.5.21 (2010-09-15).

# Usage
By default, the proxy starts on port 10143 (as defined by the LOCALPORT
constant). To use the proxy you will need to set up your e-mail reader to
connect to that port using the IMAP protocol (without SSL).

# Dependencies
* GMail account
* Perl (tested with 5.12.4, but should work with 5.10)
* POE
* POE::Component::SSLify
* Regexp::Common
* Encode::IMAPUTF7

For Debian:
```sh
apt-get install libpoe-component-sslify-perl libregexp-common-perl
```

# ACK
Thanks to Paul DeCarlo <http://windotnet.blogspot.com/> for pointing out the
Gmail IMAP extensions <http://code.google.com/apis/gmail/imap/#x-gm-labels>
that made this a whole lot easier than what I had originally planned on doing.
