proc toOcta*(apt : float) : int = int(apt * 100000000) ## convert aptos coin to octa units

proc toApt*(octa : int) : float = octa / 100000000 ## convert octa units to aptos coins
