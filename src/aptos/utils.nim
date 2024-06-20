#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
proc toOcta*(apt: float): int = int(apt * 100000000) ## convert aptos coin to octa units

proc toApt*(octa: int): float = octa / 100000000 ## convert octa units to aptos coins
