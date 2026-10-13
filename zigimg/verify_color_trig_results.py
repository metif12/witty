"""Exact historical color pins and retained caller-optimization differences."""
import hashlib

EMPTY_SHA256 = hashlib.sha256(b'').hexdigest()
# Source Debug/ordinary V and Source ReleaseSafe/production V respectively.
COLOR_RESULTS = {
    ('color_science', False): (6961,
        'd97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566',
        'd97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566', 0, EMPTY_SHA256),
    ('color_science', True): (6961,
        '0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8',
        '0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8', 0, EMPTY_SHA256),
    ('color_space', False): (5792,
        '262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0',
        '262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0', 0, EMPTY_SHA256),
    ('color_space', True): (5792,
        'f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba',
        '2043e0e258e164d0671082d5a356d5a80c2f993580dee63aae38c8258e6d79cd',
        16, 'e32e3f667c6a3c4e437f9fd658f7f3e10a3f32f67b835f944d958ca9ae5064d1'),
}


def compare_color_records(label, cases, native, translated, v_prod):
    count, source_hash, v_hash, different, difference_hash = COLOR_RESULTS[label, v_prod]
    if len(cases) != count or len(native) != count or len(translated) != count:
        raise AssertionError(label + ': color count changed')
    if (hashlib.sha256(b'\n'.join(native)).hexdigest() != source_hash
            or hashlib.sha256(b'\n'.join(translated)).hexdigest() != v_hash):
        raise AssertionError(label + ': color result hash changed')
    h, differences = hashlib.sha256(), []
    for (name, row), expected, actual in zip(cases, native, translated):
        if expected != actual:
            h.update(name.encode() + b'\0' + expected + b'\0' + actual + b'\n')
            differences.append(dict(name=name, input=row, source=expected.decode(), v=actual.decode(),
                                    columns=[i for i, (a, b) in enumerate(zip(expected.split(b','), actual.split(b','))) if a != b]))
    if len(differences) != different or h.hexdigest() != difference_hash:
        raise AssertionError(label + ': retained color differences changed')
    return dict(returning_records=count, matching_records=count - different,
                source_sha256=source_hash, v_sha256=v_hash, differing_records=different,
                difference_sha256=h.hexdigest()), differences
