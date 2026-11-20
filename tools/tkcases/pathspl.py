"""PATHSPL: no parameters (156), all five variables (SET shows them and
the order they were set in), only some (empty fields between commas, with
and without blanks), blanks as separators, a name without device or path,
lower case, wild cards, a device name, no name, ..; the variables
shown with ECHO (SDX takes $NAME] as the variable NAME]: blanks after
the names). Drive letters F: G: J: L:, which no CIO device has (on EOS a
CIO device's letter is that device: test ddrive)."""
from tk_test import case

P = 'UTILS/SHELLUTL/PATHSPL/PATHSPL.COM'
CASES = {
    'pathspl': case(P, ['PATHSPL', 'PATHSPL F:>FOO>BAR.EXE %D,%P,%F,%B,%X', 'SET',
                        'PATHSPL F:>FOO>BAR.EXE,,,,,YX', 'ECHO $YX']),
    'pathspl-2': case(P, ['PATHSPL A:>X>Y.Z ,,A3', 'ECHO $A3', 'PATHSPL B:>X>Y.Z B1 B2', 'ECHO $B1 $B2',
                          'PATHSPL G:>Y.Z C1, ,C3', 'ECHO $C1 $C3', 'PATHSPL J:Y.Z  ,D2', 'ECHO $D2',
                          'PATHSPL L:>P>Q>R.S,E1,,,E4,E5', 'ECHO $E1 $E4 $E5',
                          'PATHSPL F,F1,F2,F3,F4,F5', 'ECHO $F1 : $F2 : $F3 $F4 : $F5 :',
                          'PATHSPL ,J1', 'ECHO $J1']),
    'pathspl-3': case(P, ['pathspl d2:>dir>sub>file.ext g1,g2,g3,g4,g5', 'ECHO $G1 $G2 $G3 $G4 $G5',
                          'PATHSPL A*.?X H1,H2,H3,H4,H5', 'ECHO $H1 $H2 $H3 $H4 $H5',
                          'PATHSPL CAR:X.Y I1,,I3', 'ECHO $I1 $I3', 'PATHSPL >SUB> K2,K3,K4',
                          'ECHO $K2 : $K3 : $K4 :', 'PATHSPL D1:..>A.B L1,L2', 'ECHO $L1 $L2']),
}
