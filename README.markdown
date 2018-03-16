# gmail-imap-label

## Description

Proxy that sits between an IMAP client and Gmail's IMAPS server and adds GMail
labels to the X-Label header.

Tested with mutt (v1.5.21) and offlineimap (v6.3.4).

## Usage

By default, the proxy starts on port 10143, however another port can be
specified via a command-line option. To use the proxy, you will need to set up
your e-mail reader to connect to that port using the IMAP protocol (without
SSL).

## Installation

To install the Debian package:

```
apt-get install libnet-gmail-imap-label-perl
```

## See also

* [Git repository](https://github.com/zmughal/gmail-imap-label)
* [CPAN module](http://p3rl.org/Net::Gmail::IMAP::Label)

## ACK

Thanks to Paul DeCarlo <http://pjdecarlo.com/> for pointing out the
Gmail IMAP extensions <https://developers.google.com/gmail/imap/imap-extensions#access_to_gmail_labels_x-gm-labels>
that made this a whole lot easier than what I had originally planned on doing.
