#!/usr/bin/env python3
# renew-truenas-tls.py -- re-issue tailscale LE cert for truenas.tail54538d.ts.net,
# re-import into TrueNAS cert store, rebind web UI. Idempotent: only re-imports when
# the SHA1 fingerprint actually changes from the UI-bound cert. Run weekly via cron.
# Requires: TrueNAS Tailscale app container "ix-tailscale-tailscale-1" running.
# Revert UI to self-signed: midclt call system.general.update "{\"ui_certificate\":1}"
import subprocess, json, os, shutil, tempfile, time, hashlib, datetime, sys
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from truenas_api_client import Client

CERT_NAME = "truenas_tailscale"
DOMAIN    = "truenas.tail54538d.ts.net"
CONT      = "ix-tailscale-tailscale-1"

def log(msg): t = datetime.datetime.utcnow().strftime("%FT%TZ"); print(f"[{t}] {msg}", flush=True)

def sha1_fp_cert_pem(pem_bytes: bytes) -> str:
    c = x509.load_pem_x509_certificate(pem_bytes)
    return c.fingerprint(hashes.SHA1()).hex().upper()

def docker(*args, **kw):
    return subprocess.run(["docker"]+list(args), check=True, capture_output=True, text=True, **kw)

def issue_cert() -> bytes:
    work = tempfile.mkdtemp()
    try:
        docker("exec", "-u","0","-w","/tmp", CONT, "sh","-c",
               f"rm -f /tmp/{DOMAIN}.crt /tmp/{DOMAIN}.key && tailscale cert --min-validity=720h {DOMAIN} >/dev/null")
        docker("cp", f"{CONT}:/tmp/{DOMAIN}.crt", os.path.join(work,"cert.crt"))
        docker("cp", f"{CONT}:/tmp/{DOMAIN}.key", os.path.join(work,"cert.key"))
        os.chmod(os.path.join(work,"cert.key"), 0o600)
        with open(os.path.join(work,"cert.crt"),"rb") as f: return f.read()
        with open(os.path.join(work,"cert.key"), "rb") as f: return f.read()
    finally:
        shutil.rmtree(work, ignore_errors=True)

def main():
    log("issuing cert in container (min-validity 720h)")
    # need both cert and key for create; reuse two-shot via /tmp of container
    tmpd = tempfile.mkdtemp()
    try:
        docker("exec","-u","0","-w","/tmp",CONT,"sh","-c",
               f"rm -f /tmp/{DOMAIN}.crt /tmp/{DOMAIN}.key && tailscale cert --min-validity=720h {DOMAIN} >/dev/null")
        docker("cp",f"{CONT}:/tmp/{DOMAIN}.crt",os.path.join(tmpd,"cert.crt"))
        docker("cp",f"{CONT}:/tmp/{DOMAIN}.key",os.path.join(tmpd,"cert.key"))
        os.chmod(os.path.join(tmpd,"cert.key"),0o600)
        crt = open(os.path.join(tmpd,"cert.crt"),"rb").read()
        key = open(os.path.join(tmpd,"cert.key"),"rb").read()
    finally:
        shutil.rmtree(tmpd, ignore_errors=True)
    new_fp = sha1_fp_cert_pem(crt)
    log(f"new cert fp={new_fp}")

    c = Client()
    # Get currently UI-bound cert
    cfg = c.call("system.general.config")
    ui_cert = cfg.get("ui_certificate")
    active_id = None; active_fp = None
    if ui_cert and isinstance(ui_cert, dict):
        active_id = ui_cert.get("id")
        try:
            inst = c.call("certificate.get_instance", active_id)
            active_fp = inst.get("fingerprint","").replace(":","").upper() or None
        except Exception as e:
            log(f"WARN: could not fetch active cert id={active_id}: {e}")
    log(f"active UI cert id={active_id} fp={active_fp}")

    if new_fp and active_fp and new_fp == active_fp:
        # cleanup any stray orphans named _new_* not UI-bound
        for x in c.call("certificate.query"):
            if x["name"].startswith(CERT_NAME+"_new_") and x["id"] != active_id:
                log(f"cleanup orphan cert id={x["id"]} name={x["name"]}")
                try: jc(c, "certificate.delete", x["id"])
                except Exception as e: log(f"  delete failed: {e}")
        log("fingerprint matches UI-bound cert; nothing to do. Exit 0.")
        return 0

    log(f"fingerprint differs from active (UI-bound) cert; re-importing.")
    tmp_name = f"{CERT_NAME}_new_{int(time.time())}"
    jc(c, "certificate.create", {"name": tmp_name, "create_type":"CERTIFICATE_CREATE_IMPORTED",
                                 "certificate": crt.decode(), "privatekey": key.decode()})
    new_cert = None
    for x in c.call("certificate.query"):
        if x["name"] == tmp_name: new_cert = x; break
    if not new_cert:
        log("ERROR: created cert not found in DB after create"); return 1
    new_id = new_cert["id"]
    log(f"new cert id={new_id} name={tmp_name}")

    # bind UI + restart http
    jc(c, "system.general.update", {"ui_certificate": int(new_id)})
    jc(c, "service.control", "RESTART", "http")
    time.sleep(3)

    # verify live
    live_pem = subprocess.run(["sh","-c",f"echo | openssl s_client -connect 127.0.0.1:443 -servername {DOMAIN} 2>/dev/null | openssl x509"],
                              shell=False, capture_output=True).stdout
    try:
        live_fp = sha1_fp_cert_pem(live_pem)
        log(f"live UI cert fp={live_fp}")
        if live_fp != new_fp: log(f"WARNING: live fp mismatch (expected {new_fp})")
    except Exception as e:
        log(f"WARN: could not parse live cert: {e}")

    # delete old UI cert
    if active_id and active_id != new_id:
        log(f"deleting old UI cert id={active_id}")
        try: jc(c, "certificate.delete", int(active_id))
        except Exception as e: log(f"  delete failed: {e}")

    # rename new -> canonical
    log(f"renaming id={new_id} -> {CERT_NAME}")
    try: jc(c, "certificate.update", int(new_id), {"name": CERT_NAME})
    except Exception as e: log(f"  rename failed (cert still works as {tmp_name}): {e}")

    # cleanup any other stray _new_ orphans
    for x in c.call("certificate.query"):
        if x["name"].startswith(CERT_NAME+"_new_"):
            log(f"cleanup leftover orphan cert id={x["id"]} name={x["name"]}")
            try: jc(c, "certificate.delete", x["id"])
            except Exception as e: log(f"  delete failed: {e}")

    log("renewal complete.")
    return 0

def jc(c, method, *args, timeout=60):
    # call a jobbed method, wait for completion, return result dict
    jid = c.call(method, *args)
    if not isinstance(jid, int):  # not a jobbed method, returned directly
        return jid
    end = time.time() + timeout
    while time.time() < end:
        for j in c.call("core.get_jobs"):
            if j["id"] == jid:
                if j["state"] in ("SUCCESS","FAILED","ABORTED"):
                    if j["state"] != "SUCCESS":
                        raise RuntimeError(f"{method}: job {jid} {j["state"]}: {j.get("error") or j.get("exception")}")
                    return j.get("result")
                break
        time.sleep(0.5)
    raise TimeoutError(f"{method}: job {jid} did not complete in {timeout}s")

if __name__ == "__main__":
    sys.exit(main())
