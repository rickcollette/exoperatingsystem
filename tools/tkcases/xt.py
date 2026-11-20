"""XT: no command (the usage line), a built-in command, a program and its
parameters. xt-err: a program that is not there (its error, then the
time), a command with redirection, blanks before the command. xt-nest:
XT timing XT (both times; EOS's XCOMLI does not return to the outer XT
yet). The times differ from run to run: no_times."""
from tk_test import case, no_times, TKX

HEXDEC = (TKX / 'UTILS/SHELLUTL/HEXDEC/HEXDEC.COM').read_bytes()
XT = 'UTILS/SHELLUTL/XT/XT.COM'

CASES = {
    'xt': case(XT, ['XT', 'XT ECHO HELLO', 'XT TYPE A.TXT', 'XT HEXDEC 255', 'ECHO end'],
               files={'A.TXT': b'line one\x9bline two\x9b', 'HEXDEC.COM': HEXDEC}, norm=no_times),
    'xt-err': case(XT, ['XT NOSUCH', 'ECHO after', 'XT ECHO hi >>O.TXT', 'TYPE O.TXT',
                        'XT   ECHO spaced', 'ECHO end'], norm=no_times),
    'xt-nest': case(XT, ['ECHO start', 'XT XT ECHO two', 'ECHO end'], norm=no_times),
}
