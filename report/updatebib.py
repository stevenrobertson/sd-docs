#!/usr/bin/python

def main():
    src = open('/home/steven/Documents/CUDA flame algorithm.bib').read()
    # Something in the Windows chain breaks if the result contains UTF-8.
    # This will simply bail if it fails to convert, requiring manual
    # intervention to replace the offending Unicode char in Mendeley
    src = src.decode('utf-8').encode('ascii')
    things = src.split('@')[1:]
    getkey = lambda s: s.split('{', 1)[1].split(',', 1)[0]
    dropfile = lambda t: '@' + '\n'.join(
            [s for s in t.split('\n') if not s.startswith('file')])
    refs = { getkey(t): dropfile(t) for t in things }
    with open('mendeley.bib', 'w') as f:
        f.write('\n'.join(refs[k] for k in sorted(refs.keys())))

if __name__ == "__main__":
    main()
