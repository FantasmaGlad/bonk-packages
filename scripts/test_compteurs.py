import datetime
import json
import tempfile
import unittest
from pathlib import Path

import compteurs


def groupe(chemin: str, statut: int, nombre: int) -> dict:
    return {"count": nombre, "dimensions": {"clientRequestPath": chemin, "edgeResponseStatus": statut}}


class Canaux(unittest.TestCase):
    def test_chaque_chemin_va_a_son_canal(self):
        cas = [
            ("/dl/homebrew/v0.1.6/bonk-0.1.6-macos-aarch64.tar.gz", 302, "homebrew"),
            ("/dl/homebrew/v0.1.6/bonk-cli-0.1.6-linux-x86_64.tar.gz", 302, "homebrew"),
            ("/dl/script/v0.1.6/bonk-cli-0.1.6-windows-x86_64.zip", 302, "script"),
            ("/dl/script/v0.1.6/SHA256SUMS", 302, None),
            ("/dl/scoop/v0.1.6/bonk-0.1.6-windows-x86_64.zip", 302, "scoop"),
            ("/debian/pool/bonk_0.1.6-1_amd64.deb", 200, "apt"),
            ("/debian/pool/bonk_0.1.6-1_amd64.deb", 304, None),
            ("/debian/dists/stable/InRelease", 200, None),
            ("/rpm/x86_64/bonk-0.1.6-1.x86_64.rpm", 200, "rpm"),
            ("/arch/x86_64/bonk-0.1.6-1-x86_64.pkg.tar.zst", 200, "pacman"),
            ("/arch/x86_64/bonk-0.1.6-1-x86_64.pkg.tar.zst.sig", 200, None),
            ("/termux/pool/bonk_0.1.6_aarch64.deb", 200, "termux"),
            ("/dl/homebrew/v0.1.6/bonk-0.1.6-macos-aarch64.tar.gz", 404, None),
        ]
        for chemin, statut, attendu in cas:
            with self.subTest(chemin=chemin, statut=statut):
                self.assertEqual(compteurs.canal(chemin, statut), attendu)

    def test_les_groupes_s_additionnent_par_canal(self):
        comptes = compteurs.compter([
            groupe("/debian/pool/bonk_0.1.6-1_amd64.deb", 200, 3),
            groupe("/debian/pool/bonk-cli_0.1.6-1_arm64.deb", 200, 2),
            groupe("/index.html", 200, 40),
        ])
        self.assertEqual(comptes["apt"], 5)
        self.assertEqual(sum(comptes.values()), 5)


class Registre(unittest.TestCase):
    def test_totaux_et_badges_de_tous_les_jours(self):
        with tempfile.TemporaryDirectory() as racine:
            dossier = Path(racine)
            (dossier / "jours").mkdir()
            for jour, apt, homebrew in (("2026-11-28", 900, 4), ("2026-11-29", 450, 1)):
                comptes = dict.fromkeys(compteurs.CANAUX, 0) | {"apt": apt, "homebrew": homebrew}
                (dossier / "jours" / f"{jour}.json").write_text(json.dumps(comptes))
            totaux = compteurs.ecrire_totaux(dossier)
            self.assertEqual((totaux["apt"], totaux["homebrew"]), (1350, 5))
            paquets = json.loads((dossier / "paquets.json").read_text())
            self.assertEqual((paquets["schemaVersion"], paquets["message"]), (1, "1.4k"))
            self.assertEqual(json.loads((dossier / "homebrew.json").read_text())["message"], "5")

    def test_seuls_les_jours_finis_et_non_comptes(self):
        with tempfile.TemporaryDirectory() as racine:
            dossier = Path(racine)
            (dossier / "jours").mkdir()
            (dossier / "jours" / "2026-11-27.json").write_text("{}")
            jours = compteurs.jours_a_compter(dossier, datetime.date(2026, 11, 29))
            self.assertEqual((jours[0], jours[-1]), ("2026-10-30", "2026-11-28"))
            self.assertNotIn("2026-11-27", jours)
            self.assertEqual(len(jours), compteurs.JOURS_GARDES - 1)


class Compact(unittest.TestCase):
    def test_affichage_court(self):
        for nombre, texte in ((7, "7"), (1000, "1k"), (1799, "1.8k"), (2_500_000, "2.5M")):
            self.assertEqual(compteurs.compact(nombre), texte)


if __name__ == "__main__":
    unittest.main()
