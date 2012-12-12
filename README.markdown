gmail-imap-label
# Description
Proxy that sits between an IMAP client and Gmail's IMAPS server and adds GMail
labels to the X-Label header.

Tested with mutt (v1.5.21) and offlineimap (v6.3.4).

# Usage
By default, the proxy starts on port 10143, however another port can be
specified via a command-line option. To use the proxy you will need to set up
your e-mail reader to connect to that port using the IMAP protocol (without
SSL).

# Runtime dependencies
* GMail account
* Perl (tested with 5.12.4, but should work with 5.10)
* POE
* POE::Component::SSLify
* Regexp::Common
* Encode::IMAPUTF7
* Getopt::Long::Descriptive

For Debian:
```
apt-get install libpoe-component-sslify-perl libregexp-common-perl libencode-imaputf7-perl libgetopt-long-descriptive-perl
```

# See also
* [Git repository](https://github.com/zmughal/gmail-imap-label)
* [CPAN module](http://p3rl.org/Net::Gmail::IMAP::Label)

# ACK
Thanks to Paul DeCarlo <http://windotnet.blogspot.com/> for pointing out the
Gmail IMAP extensions <http://code.google.com/apis/gmail/imap/#x-gm-labels>
that made this a whole lot easier than what I had originally planned on doing.
