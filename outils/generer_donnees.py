#!/usr/bin/env python3
"""Genere data/pokemon.json, attaques.json, types.json, talents.json, natures.json, courbes.json
a partir des CSV de PokeAPI (https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv).

Usage :  python outils/generer_donnees.py [dossier_csv] [dossier_sortie]
         (telecharge les CSV dans ./csv_pokeapi s'ils sont absents)
Les stats/types/talents sont ceux de la derniere generation ; les attaques apprises (niveau, CT, CS, tuteurs)
sont celles de Rouge Feu / Vert Feuille (version_group 7).
Options en haut du fichier : PREMIER / DERNIER (numeros de Pokedex a inclure) pour etendre le jeu plus tard.
"""
import csv, json, os, re, sys, unicodedata, urllib.request, colorsys

PREMIER, DERNIER = 1, 151
GEN_ATTAQUES_MAX = 3          # toutes les attaques des gen 1 a 3 sont incluses, plus celles apprises par les especes retenues
VG = 7                        # Rouge Feu / Vert Feuille
FR = '5'
BASE = 'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/'
FICHIERS = ['pokemon','pokemon_species','pokemon_species_names','pokemon_stats','pokemon_types','pokemon_abilities',
 'pokemon_evolution','pokemon_moves','pokemon_egg_groups','egg_groups','moves','move_names','move_meta','move_meta_ailments',
 'move_meta_stat_changes','move_effect_prose','machines','items','item_names','type_names','type_efficacy','types','abilities','ability_names',
 'ability_prose','natures','nature_names','stats','experience','growth_rates','move_targets']

dossier_csv = sys.argv[1] if len(sys.argv) > 1 else 'csv_pokeapi'
sortie = sys.argv[2] if len(sys.argv) > 2 else 'data'
os.makedirs(dossier_csv, exist_ok=True)
for f in FICHIERS:
    p = os.path.join(dossier_csv, f + '.csv')
    if not os.path.exists(p):
        print('telechargement', f)
        urllib.request.urlretrieve(BASE + f + '.csv', p)

def lire(nom):
    with open(os.path.join(dossier_csv, nom + '.csv'), encoding='utf-8', newline='') as fh:
        return list(csv.DictReader(fh))

def slug(s):
    s = s.replace('♀', '_f').replace('♂', '_m')
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    s = re.sub(r"[^a-z0-9]+", '_', s).strip('_')
    return s

def entier(v, d=None):
    return int(v) if v not in ('', None) else d

# ---------- types ----------
types_id = {r['id']: r['identifier'] for r in lire('types')}
noms_types = {r['type_id'] if 'type_id' in r else r['id']: r['name'] for r in lire('type_names') if r['local_language_id'] == FR}
tid_fr = {}
for tid, ident in types_id.items():
    if ident in ('unknown', 'shadow', 'stellar'):
        continue
    tid_fr[tid] = slug(noms_types.get(tid, ident))
eff = {}
for r in lire('type_efficacy'):
    a, d = r['damage_type_id'], r['target_type_id']
    if a in tid_fr and d in tid_fr and r['damage_factor'] != '100':
        eff.setdefault(tid_fr[a], {})[tid_fr[d]] = int(r['damage_factor']) / 100.0
types_json = {
    'types': list(tid_fr.values()),
    'noms': {v: noms_types[k] for k, v in tid_fr.items()},
    'efficacite': eff,
}

# ---------- courbes d'experience ----------
GR = {'slow': 'lente', 'medium': 'moyenne', 'fast': 'rapide', 'medium-slow': 'moyenne_lente',
      'slow-then-very-fast': 'erratique', 'fast-then-very-slow': 'fluctuante'}
gr_id = {r['id']: GR.get(r['identifier'], r['identifier']) for r in lire('growth_rates')}
courbes = {}
for r in lire('experience'):
    courbes.setdefault(gr_id[r['growth_rate_id']], {})[int(r['level'])] = int(r['experience'])
courbes_json = {k: [v[i] for i in range(1, 101)] for k, v in courbes.items()}

# ---------- natures ----------
STAT = {'1': 'pv', '2': 'atk', '3': 'def', '4': 'spa', '5': 'spd', '6': 'vit', '7': 'precision', '8': 'esquive'}
nat_noms = {r['nature_id']: r['name'] for r in lire('nature_names') if r['local_language_id'] == FR}
natures_json = {}
for r in lire('natures'):
    n = {'nom': nat_noms[r['id']]}
    if r['increased_stat_id'] != r['decreased_stat_id']:
        n['plus'] = STAT[r['increased_stat_id']]
        n['moins'] = STAT[r['decreased_stat_id']]
    natures_json[slug(n['nom'])] = n

# ---------- talents ----------
ab_ident = {r['id']: r['identifier'] for r in lire('abilities')}
ab_nom = {r['ability_id']: r['name'] for r in lire('ability_names') if r['local_language_id'] == FR}
ab_desc = {r['ability_id']: r['short_effect'] for r in lire('ability_prose') if r['local_language_id'] == FR}
ab_slug = {}
talents_json = {}
def talent(aid):
    if aid not in ab_slug:
        s = slug(ab_nom.get(aid, ab_ident[aid]))
        ab_slug[aid] = s
        talents_json[s] = {'nom': ab_nom.get(aid, ab_ident[aid]), 'description': ab_desc.get(aid, ''), 'id_anglais': ab_ident[aid]}
    return ab_slug[aid]

# ---------- especes ----------
esp = {r['id']: r for r in lire('pokemon_species')}
esp_nom = {r['pokemon_species_id']: r['name'] for r in lire('pokemon_species_names') if r['local_language_id'] == FR}
poke = {r['species_id']: r for r in lire('pokemon') if r['is_default'] == '1'}
retenues = [str(n) for n in range(PREMIER, DERNIER + 1)]
sid_slug = {s: slug(esp_nom[s]) for s in retenues}
base_stats, ev_stats = {}, {}
for r in lire('pokemon_stats'):
    base_stats.setdefault(r['pokemon_id'], {})[STAT[r['stat_id']]] = int(r['base_stat'])
    if int(r['effort']):
        ev_stats.setdefault(r['pokemon_id'], {})[STAT[r['stat_id']]] = int(r['effort'])
ptypes = {}
for r in lire('pokemon_types'):
    ptypes.setdefault(r['pokemon_id'], []).append((int(r['slot']), tid_fr[r['type_id']]))
pab = {}
for r in lire('pokemon_abilities'):
    pab.setdefault(r['pokemon_id'], []).append((r['is_hidden'] == '1', int(r['slot']), r['ability_id']))
grp = {r['id']: r['identifier'] for r in lire('egg_groups')}
oeufs = {}
for r in lire('pokemon_egg_groups'):
    oeufs.setdefault(r['species_id'], []).append(grp[r['egg_group_id']])

COUL = {'1': '#3a3a3a', '2': '#4a86d8', '3': '#8a5a35', '4': '#8d8d8d', '5': '#4fa86b', '6': '#e88fb4', '7': '#8e5cc4', '8': '#d84a3a', '9': '#e8e8e8', '10': '#e8c93a'}
def teinte_alt(hexa):
    r, g, b = [int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb((h + 0.45) % 1.0, min(0.75, l + 0.05), max(0.5, s))
    return '#%02x%02x%02x' % (int(r * 255), int(g * 255), int(b * 255))

# couleurs deja choisies dans le projet : conservees
anciennes = {}
chemin_old = os.path.join(sortie, 'pokemon.json')
if os.path.exists(chemin_old):
    try:
        anciennes = json.load(open(chemin_old, encoding='utf-8'))
    except Exception:
        pass

# ---------- attaques ----------
mv_nom = {r['move_id']: r['name'] for r in lire('move_names') if r['local_language_id'] == FR}
mv_slug_id = {}
mv = {r['id']: r for r in lire('moves')}
CLASSE = {'1': 'statut', '2': 'physique', '3': 'speciale'}
for mid in mv:
    if mid in mv_nom:
        mv_slug_id[mid] = slug(mv_nom[mid])
# eviter les doublons de slug
vus = {}
for mid, s in list(mv_slug_id.items()):
    if s in vus:
        mv_slug_id[mid] = s + '_' + mid
    vus[s] = mid
tg = {r['id']: r['identifier'] for r in lire('move_targets')}
meta = {r['move_id']: r for r in lire('move_meta')}
AIL = {'1': 'paralysie', '2': 'sommeil', '3': 'gel', '4': 'brulure', '5': 'poison', '6': 'confusion', '7': 'attraction',
       '8': 'piege', '9': 'cauchemar', '12': 'tourment', '13': 'entrave', '14': 'bailler', '15': 'anti_soin',
       '17': 'sans_immunite', '18': 'vampigraine', '19': 'embargo', '20': 'requiem', '21': 'racines', '24': 'silence'}
chg = {}
for r in lire('move_meta_stat_changes'):
    chg.setdefault(r['move_id'], []).append((STAT[r['stat_id']], int(r['change'])))
prose = {r['move_effect_id']: r for r in lire('move_effect_prose') if r['local_language_id'] == '9'}

machines = {}
for r in lire('machines'):
    if r['version_group_id'] == str(VG):
        machines[r['move_id']] = int(r['machine_number'])

# apprentissages FRLG
appr = {}
for r in lire('pokemon_moves'):
    if r['version_group_id'] != str(VG) or r['pokemon_id'] not in retenues:
        continue
    d = appr.setdefault(r['pokemon_id'], {'niveau': [], 'ct': set(), 'cs': set(), 'tuteur': set(), 'oeuf': set()})
    m = r['move_id']
    meth = r['pokemon_move_method_id']
    if meth == '1':
        d['niveau'].append((int(r['level']), int(r['order'] or 0), m))
    elif meth == '4':
        (d['cs'] if machines.get(m, 0) >= 100 else d['ct']).add(m)
    elif meth == '3':
        d['tuteur'].add(m)
    elif meth == '2':
        d['oeuf'].add(m)

utilisees = set()
for d in appr.values():
    for _, _, m in d['niveau']:
        utilisees.add(m)
    for k in ('ct', 'cs', 'tuteur', 'oeuf'):
        utilisees |= d[k]

attaques_json = {}
for mid, r in mv.items():
    if mid not in mv_slug_id:
        continue
    if int(r['generation_id']) > GEN_ATTAQUES_MAX and mid not in utilisees:
        continue
    if r['type_id'] not in tid_fr:
        continue
    a = {'nom': mv_nom[mid], 'type': tid_fr[r['type_id']], 'categorie': CLASSE[r['damage_class_id']],
         'puissance': entier(r['power'], 0), 'precision': entier(r['accuracy'], 0), 'pp': entier(r['pp'], 5),
         'id_en': r['identifier'], 'priorite': int(r['priority']), 'cible': tg.get(r['target_id'], 'selected-pokemon'), 'effet_id': int(r['effect_id'])}
    if a['precision'] == 0:
        a['precision'] = 0     # 0 = ne rate jamais
    if r['effect_chance']:
        a['chance_effet'] = int(r['effect_chance'])
    if mid in machines:
        n = machines[mid]
        a['machine'] = ('CS%02d' % (n - 100)) if n >= 100 else ('CT%02d' % n)
    m = meta.get(mid)
    e = {}
    if m:
        if m['meta_ailment_id'] in AIL:
            e['statut'] = AIL[m['meta_ailment_id']]
            e['statut_chance'] = int(m['ailment_chance']) or 100
        if int(m['flinch_chance']):
            e['peur'] = int(m['flinch_chance'])
        if m['min_hits']:
            e['coups'] = [int(m['min_hits']), int(m['max_hits'])]
        if m['min_turns']:
            e['tours'] = [int(m['min_turns']), int(m['max_turns'])]
        dr = int(m['drain'])
        if dr > 0:
            e['drain'] = dr
        elif dr < 0:
            e['recul'] = -dr
        if int(m['healing']):
            e['soin'] = int(m['healing'])
        if int(m['crit_rate']):
            e['crit'] = int(m['crit_rate'])
        if mid in chg:
            sur_soi = r['target_id'] == '7' or m['meta_category_id'] in ('7',)
            e['stades'] = [{'stat': s, 'delta': d, 'sur': 'soi' if sur_soi else 'cible'} for s, d in chg[mid]]
            e['stades_chance'] = int(m['stat_chance']) or 100
        e['meta'] = int(m['meta_category_id'])
    if e:
        a['effets'] = e
    if r['effect_id'] in prose:
        a['description_en'] = prose[r['effect_id']]['short_effect']
    attaques_json[mv_slug_id[mid]] = a

# ---------- evolutions ----------
evo = {}
for r in lire('pokemon_evolution'):
    if r['evolved_pokemon_form_id'] or r['region_id']:
        continue   # evolutions vers des formes regionales : ignorees
    cible = r['evolved_species_id']
    src = esp[cible]['evolves_from_species_id']
    if cible not in retenues or src not in retenues:
        continue
    e = {'vers': sid_slug[cible]}
    t = r['evolution_trigger_id']
    if t == '1':
        if r['minimum_level']:
            e['niveau'] = int(r['minimum_level'])
        if r['minimum_happiness']:
            e['bonheur'] = int(r['minimum_happiness'])
        if r['time_of_day']:
            e['moment'] = 'jour' if r['time_of_day'] == 'day' else 'nuit'
        if r['gender_id']:
            e['genre'] = 'f' if r['gender_id'] == '1' else 'm'
        if r['known_move_id'] and r['known_move_id'] in mv_slug_id:
            e['attaque_connue'] = mv_slug_id[r['known_move_id']]
        if r['relative_physical_stats'] != '':
            e['stats_relatives'] = int(r['relative_physical_stats'])
    elif t == '2':
        e['echange'] = True
        if r['held_item_id']:
            e['objet_tenu'] = r['held_item_id']
    elif t == '3':
        e['objet'] = r['trigger_item_id']
    else:
        e['declencheur'] = t
    if e not in evo.setdefault(src, []):
        evo[src].append(e)
items = {r['id']: r['identifier'] for r in lire('items')}
inom = {r['item_id']: r['name'] for r in lire('item_names') if r['local_language_id'] == FR}
for lst in evo.values():
    for e in lst:
        for k in ('objet', 'objet_tenu'):
            if k in e:
                e[k] = slug(inom.get(e[k], items[e[k]]))

# ---------- assemblage des especes ----------
pokemon_json = {}
for sid in retenues:
    pid = poke[sid]['id']
    e = esp[sid]
    ids = sid_slug[sid]
    ts = [t for _, t in sorted(ptypes[pid])]
    ab = sorted(pab[pid], key=lambda x: x[1])
    normaux = [talent(a) for h, _, a in ab if not h]
    cache = [talent(a) for h, _, a in ab if h]
    genre = int(e['gender_rate'])
    d = {
        'numero': int(sid), 'nom': esp_nom[sid], 'types': ts,
        'couleur': anciennes.get(ids, {}).get('couleur') or COUL[e['color_id']],
        'base': base_stats[pid], 'talents': list(dict.fromkeys(normaux)), 'talent_cache': cache[0] if cache else '',
        'taux_capture': int(e['capture_rate']), 'exp_base': int(poke[sid]['base_experience']),
        'courbe': gr_id[e['growth_rate_id']], 'pct_femelle': -1 if genre == -1 else genre * 12.5,
        'bonheur_base': int(e['base_happiness']), 'ev': ev_stats.get(pid, {}),
        'pas_eclosion': int(e['hatch_counter']), 'groupes_oeuf': oeufs.get(sid, []),
        'taille': int(poke[sid]['height']) / 10.0, 'poids': int(poke[sid]['weight']) / 10.0,
        'legendaire': e['is_legendary'] == '1' or e['is_mythical'] == '1',
    }
    d['couleur_shiny'] = teinte_alt(d['couleur'])
    if sid in evo:
        d['evolutions'] = evo[sid]
    a = appr.get(sid, {'niveau': [], 'ct': set(), 'cs': set(), 'tuteur': set(), 'oeuf': set()})
    d['attaques_niveau'] = [[l, mv_slug_id[m]] for l, _, m in sorted(a['niveau']) if m in mv_slug_id]
    d['capacites'] = {k: sorted(mv_slug_id[m] for m in a[k] if m in mv_slug_id) for k in ('ct', 'cs', 'tuteur', 'oeuf')}
    pokemon_json[ids] = d

def ecrire(nom, data):
    os.makedirs(sortie, exist_ok=True)
    with open(os.path.join(sortie, nom), 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(data, fh, ensure_ascii=False, indent='\t')
        fh.write('\n')
ecrire('pokemon.json', pokemon_json)
ecrire('attaques.json', attaques_json)
ecrire('types.json', types_json)
ecrire('talents.json', talents_json)
ecrire('natures.json', natures_json)
ecrire('courbes.json', courbes_json)

# ---------- rencontres sauvages (Rouge Feu) : data/rencontres_modele.json, a copier/adapter dans data/rencontres.json ----------
METHODES = {'1': 'herbe', '5': 'eau', '2': 'canne', '3': 'canne', '4': 'canne'}
loc_id = {r['identifier']: r['id'] for r in lire('locations')}
zones = {}
for r in lire('location_areas'):
    zones.setdefault(r['location_id'], []).append(r['id'])
fentes = {r['id']: r for r in lire('encounter_slots')}
pid_slug = {poke[s]['id']: sid_slug[s] for s in retenues}
modele = {}
rencontres = lire('encounters')
for ident, lid in loc_id.items():
    if not ident.startswith('kanto-'):
        continue
    carte_id = ident[len('kanto-'):].replace('-', '_')
    aires = set(zones.get(lid, []))
    for r in rencontres:
        if r['version_id'] != '10' or r['location_area_id'] not in aires or r['pokemon_id'] not in pid_slug:
            continue
        f = fentes[r['encounter_slot_id']]
        m = METHODES.get(f['encounter_method_id'])
        if not m:
            continue
        zone = modele.setdefault(carte_id, {}).setdefault(m, {'taux': 10, 'pokemon': {}})
        cle = (pid_slug[r['pokemon_id']], int(r['min_level']), int(r['max_level']))
        zone['pokemon'][cle] = zone['pokemon'].get(cle, 0) + int(f['rarity'])
for cid, types_ in modele.items():
    for m, z in types_.items():
        z['pokemon'] = [{'espece': k[0], 'min': k[1], 'max': k[2], 'poids': v} for k, v in sorted(z['pokemon'].items(), key=lambda x: -x[1])]
ecrire('rencontres_modele.json', modele)
print('especes', len(pokemon_json), 'attaques', len(attaques_json), 'talents', len(talents_json), 'types', len(types_json['types']))
