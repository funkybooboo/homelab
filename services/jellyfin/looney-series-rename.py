#!/usr/bin/env python3
import sqlite3

DB = '/var/lib/jellyfin/data/jellyfin.db'
NEW_NAME = 'Looney Tunes Golden Collection'

c = sqlite3.connect(DB)
cur = c.cursor()
cur.execute("SELECT Id, Name, Path FROM BaseItems WHERE Type LIKE '%TV.Series%' ORDER BY Name")
rows = cur.fetchall()
for r in rows:
    print(f"  Id={r[0]}  Name='{r[1]}'  Path='{r[2]}'")
# find the Looney Tunes series
cur.execute("SELECT Id, Name FROM BaseItems WHERE Type LIKE '%TV.Series%' AND Name LIKE '%Looney%'")
row = cur.fetchone()
if not row:
    print("not found"); raise SystemExit(1)
sid, old = row
print(f"\nUPDATING  id={sid}  '{old}' -> '{NEW_NAME}'")
cur.execute("UPDATE BaseItems SET Name=? WHERE Id=?", (NEW_NAME, sid))
c.commit()
cur.execute("SELECT Name FROM BaseItems WHERE Id=?", (sid,))
print("now:", cur.fetchone()[0])
c.close()