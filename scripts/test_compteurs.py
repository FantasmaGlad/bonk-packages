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
            ("/dl/site/v0.1.6/bonk-0.1.6-windows-x86_64-setup.exe", 302, "site"),
            ("/dl/site/v0.1.6/bonk_0.1.6-1_amd64.deb", 302, "site"),
            ("/download/bonk-linux-x86_64.tar.gz/", 200, "readme"),
            ("/download/bonk-cli-windows-x86_64.zip/index.html", 200, "readme"),
            ("/download/SHA256SUMS/", 200, None),
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


class Github(unittest.TestCase):
    def test_seuls_les_fichiers_du_programme_comptent(self):
        cas = [
            ("bonk-0.1.6-linux-x86_64.tar.gz", "archive"),
            ("bonk-cli-0.1.6-windows-x86_64.zip", "archive"),
            ("bonk-0.1.6-windows-x86_64-setup.exe", "installer"),
            ("bonk-0.1.6-macos-universal.dmg", "installer"),
            ("bonk_0.1.6-1_amd64.deb", "package"),
            ("bonk-cli_0.1.6-1_i386.deb", "package"),
            ("bonk-cli-0.1.6-1.x86_64.rpm", "package"),
            ("bonk-0.1.6-1-x86_64.pkg.tar.zst", "package"),
            ("bonk-0.1.6-android-arm64.apk", "android"),
            ("SHA256SUMS", None),
            ("SHA256SUMS.asc", None),
            ("bonk-release-key.asc", None),
            ("bonk.json", None),
            ("bonk.rb", None),
            ("bonk.cdx.json", None),
            ("bonkos-bin.PKGBUILD", None),
            ("FantasmaGlad.Bonk.installer.yaml", None),
        ]
        for nom, attendu in cas:
            with self.subTest(nom=nom):
                self.assertEqual(compteurs.type_github(nom), attendu)

    def test_les_fichiers_communs_a_chaque_release_restent_distincts(self):
        self.assertEqual(compteurs.cle_github("v0.1.6", "bonk_0.1.6-1_amd64.deb"), "bonk_0.1.6-1_amd64.deb")
        self.assertEqual(compteurs.cle_github("v0.1.6", "SHA256SUMS"), "v0.1.6/SHA256SUMS")
        self.assertNotEqual(compteurs.cle_github("v0.1.0", "SHA256SUMS"), compteurs.cle_github("v0.1.6", "SHA256SUMS"))

    def test_une_release_supprimee_garde_ses_telechargements(self):
        with tempfile.TemporaryDirectory() as racine:
            dossier = Path(racine)
            compteurs.garder_github(dossier, {"bonk-0.1.5-linux-x86_64.tar.gz": 40, "bonk_0.1.6-1_amd64.deb": 3})
            gardes = compteurs.garder_github(dossier, {"bonk_0.1.6-1_amd64.deb": 5})
            self.assertEqual(gardes, {"bonk-0.1.5-linux-x86_64.tar.gz": 40, "bonk_0.1.6-1_amd64.deb": 5})


class Registre(unittest.TestCase):
    def test_un_seul_total_pour_les_badges_et_l_api(self):
        with tempfile.TemporaryDirectory() as racine:
            dossier = Path(racine)
            (dossier / "jours").mkdir()
            for jour, apt, homebrew in (("2026-11-28", 900, 4), ("2026-11-29", 450, 1)):
                comptes = dict.fromkeys(compteurs.CANAUX, 0) | {"apt": apt, "homebrew": homebrew}
                (dossier / "jours" / f"{jour}.json").write_text(json.dumps(comptes))
            github = {
                "bonk-0.1.6-windows-x86_64-setup.exe": 30,
                "bonk-cli-0.1.6-linux-x86_64.tar.gz": 20,
                "v0.1.6/SHA256SUMS": 70,
                "v0.1.6/SHA256SUMS.asc": 40,
            }
            resume = compteurs.ecrire_totaux(dossier, github)
            self.assertEqual(resume["counted_until"], "2026-11-29")
            self.assertEqual((resume["github"]["total"], resume["repositories"], resume["total"]), (50, 1350, 1400))
            self.assertEqual(resume["channels"]["homebrew"], 5)
            self.assertEqual(resume["raw"], 50 + 110 + 1350)
            self.assertEqual(json.loads((dossier / "telechargements.json").read_text()), resume)
            messages = {nom: json.loads((dossier / f"{nom}.json").read_text())["message"] for nom in ("total", "homebrew", "paquets")}
            self.assertEqual(messages, {"total": "1.4k", "homebrew": "5", "paquets": "1.4k"})

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
