import pathlib
import unicodedata

output_dir = 'samples'
output_dir_path = pathlib.Path(output_dir)

def write_chars(chars: list[str], encodings: list[str], path, repeat=1, bom=False):

    path.mkdir(parents=True, exist_ok=True)
    bom_str = '\uFEFF' if bom else ''

    for enc in encodings:
        cp_fname = path / f'{enc}.txt'
        text = f'{bom_str}## Encoding: {enc}\n'

        for combined_char in chars:
            char_names = []
            byte_repr = []

            for char in combined_char:
                char_names += [f'{unicodedata.name(char)} ({ord(char):0>4X})']
                byte_repr += [f'0x{char.encode(enc).hex().upper()}']

            byte_repr_str = ' + '.join(byte_repr)
            char_names_str = ' + '.join(char_names)
            char_text = combined_char * repeat
            text += (
                f'# {byte_repr_str}: {char_names_str} * {repeat}\n'
                f'{char_text}\n'
            )

        cp_fname.write_text(text, encoding=enc)

eight_bit_chars = ['à', '£', '€']
eight_bit_cps = ['windows-1252', 'iso-8859-15']  # All Western Europe codepages
eight_bit_path = output_dir_path / '8bit'  # This is a fun way to create Path objects, but is it obvious?

write_chars(chars=eight_bit_chars, encodings=eight_bit_cps, path=eight_bit_path)

unicode_chars = eight_bit_chars + [unicodedata.normalize('NFD', 'à'), '😀', '🇬🇧', '👍🏿',]
unicode_encs = ['utf-8', 'utf-16-le', 'utf-16-be', 'utf-32-be', 'utf-32-le']

unicode_path = output_dir_path / 'utf'
write_chars(chars=unicode_chars, encodings=unicode_encs, path=unicode_path)

unicode_bom_path = output_dir_path / 'utf-bom'
write_chars(chars=unicode_chars, encodings=unicode_encs, path=unicode_bom_path, bom=True)

unicode_bom_path = output_dir_path / 'utf-bom-repeat'
write_chars(chars=unicode_chars, encodings=unicode_encs, path=unicode_bom_path, bom=True, repeat=80)

# unicode_path = output_dir_path / 'utf'
# unicode_path.mkdir(parents=True, exist_ok=True)
#
# for enc in unicode_encs:
#     enc_fname = eight_bit_path / f'{cp}.txt'
#     enc_fname.write_text(test_test_unicode, encoding=enc)
#
#     # BOM version
#     enc_fname = eight_bit_path / f'{cp}-bom.txt'
#     enc_fname.write_text('\uFEFF' + test_test_unicode, encoding=enc)