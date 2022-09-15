import json
import subprocess
import os
import tempfile
import base64

def handler(event, context):
    #event_json = json.dumps(event)
    #context_json = json.dumps(context)
    (fpath,fname) = os.path.split(event["name"])
    result = convert(fname, event["data"])
    if result == '':
        return {
                'statusCode': 500,
                'body': ''
        }
    else:
        return {
                'statusCode': 200,
                'body': result
        }

def convert(src_name, src_data):
    encoded_string = ''
    data = base64.b64decode(src_data)
    tmpdir = tempfile.mkdtemp()
    filename = os.path.join(tmpdir, 'myfifo-'+src_name)
    with open(filename, 'wb') as tempf:
        # write stuff to file
        tempf.write(data)
    result = subprocess.run(['/src/libreoffice/lib/libreoffice/program/soffice','--safe-mode','--nolockcheck','--headless','--convert-to','pdf',filename], cwd=tmpdir,capture_output=True, encoding='UTF-8')    
    print("StdOut:" + result.stdout)
    print("StdErr:" + result.stderr)
    splited = os.path.splitext(filename)
    pdff = splited[0]+".pdf"
    if os.path.exists(pdff):
        with open(pdff, "rb") as pdf_file:
            encoded_string = base64.b64encode(pdf_file.read())
    else:
        print('FileNotExists:'+pdff)

    os.remove(filename)
    os.remove(pdff)
    os.rmdir(tmpdir)
    return encoded_string

