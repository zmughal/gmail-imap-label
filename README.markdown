gmail-imap-label
# Description
Proxy that sits between an IMAP client and Gmail's IMAPS server.

Tested with mutt 1.5.21 (2010-09-15).

Thanks to Paul DeCarlo <http://windotnet.blogspot.com/> for pointing out the
Gmail IMAP extensions <http://code.google.com/apis/gmail/imap/#x-gm-labels>
that made this a whole lot easier than what I had originally planned on doing.

# Dependencies
* GMail account
* Perl (tested with 5.12.4, but should work with 5.10)
* POE
* POE::Filter::SSL
