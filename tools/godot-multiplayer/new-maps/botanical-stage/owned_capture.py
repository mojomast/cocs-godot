"""Reuse reviewed owned capture error/child inventory in the U namespace."""
from config import R5, sha
path=R5/'owned_capture.py'
if sha(path)!='0c1b342c3c964a9f303da98b115beddd07914960477850d0a21b7d902b3f70b6':
    raise ValueError('Reviewed R5 capture supervisor changed')
if __name__=='__main__':exec(compile(path.read_text(),str(path),'exec'))
