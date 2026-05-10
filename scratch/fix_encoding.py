import codecs

path = r'D:\Documents\GitHub\msingi\msingi.ps1'
with codecs.open(path, 'r', 'utf-8') as f:
    content = f.read()

with codecs.open(path, 'w', 'utf-8-sig') as f:
    f.write(content)
