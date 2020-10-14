#!/usr/bin/env python3

from jinja2 import Template
from lxml.html import parse, tostring
import sys
from collections import OrderedDict
import os
from datetime import datetime


template = sys.argv[1]
searchname = sys.argv[2]

templatetype = os.path.splitext(os.path.basename(template))[0]
with open(template) as fp: 
    main = Template(fp.read())
with open('sw_ver_cut') as fp:
    software = parse(fp).find('body').find('dl').getchildren()

sw_ver_template = """
<table class="table">
<thead>
<th>Software</th>
<th>Version</th>
</thead>
<tbody>
{}
</tbody>
</table>
"""
sw_vers = []
for element in software:
    if element.tag == 'dt':
        sw_vers.append('<tr><td>{}</td>'.format(element.text))
    else:
        sw_vers.append('<td>{}</td></tr>'.format(element.text))



titles = {
          'deqms': 'DEqMS results',
          'pca': 'Principal component analysis',
          }
featnames = {
        'qc_full': {'ensg': 'ENSGs', 'peptides': 'Peptides', 'proteins': 'Proteins', 'genes': 'Gene Names'},
        }

graphs = OrderedDict()
feattypes = {
    'qc_full': ['peptides', 'proteins', 'genes', 'assoc'],
    }

for feat in feattypes[templatetype]:
    try:
        with open('{}.html'.format(feat)) as fp:
            graphs[feat] = {x.attrib['id']: tostring(x, encoding='unicode') for x in parse(fp).find('body').findall('div') if 'class' in x.attrib and x.attrib['class'] == 'chunk'}
    except IOError as e:
        print(feat, e)

def parse_table(fn):
    table = {'_rows': {}}
    with open(fn) as fp:
        header = next(fp).strip('\n').split('\t')
        table['_fields'] = sorted(header, key=lambda x: field_order[x] if x in field_order else len(field_order)+1)
        for line in fp:
            line = line.strip('\n').split('\t')
            line = {header[x]: line[x] for x in range(0,len(line))}
            table['_rows'][line[header[0]]] = line
    return table

with open('qc.html'.format(templatetype), 'w') as fp:
    fp.write(main.render(searchname=searchname, titles=titles, featnames=featnames[templatetype], features=graphs, software=sw_ver_template.format('\n'.join(sw_vers)), completedate=datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S')))
