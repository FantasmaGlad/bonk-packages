import datetime
import json
import tempfile
import unittest
from pathlib import Path

import compteurs


import ipaddress

RUNNERS = [ipaddress.ip_network("4.148.0.0/16"), ipaddress.ip_network("2a01:111::/32")]


def groupe(chemin: str, statut: int, nombre: int, adresse: str = "203.0.113.7") -> dict:
    return {
        "count": nombre,
        "dimensions": {"clientRequestPath": chemin, "edgeResponseStatus": statut, "clientIP": adresse},
    }


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
        ], RUNNERS)
        self.assertEqual(comptes["all"]["apt"], 5)
        self.assertEqual(sum(comptes["all"].values()), 5)

    def test_les_executeurs_de_github_ne_sont_pas_des_appareils(self):
        comptes = compteurs.compter([
            groupe("/dl/script/v0.1.6/bonk-cli-0.1.6-linux-x86_64.tar.gz", 302, 30, "4.148.12.9"),
            groupe("/dl/script/v0.1.6/bonk-cli-0.1.6-linux-x86_64.tar.gz", 302, 4, "198.51.100.20"),
            groupe("/termux/pool/bonk_0.1.6_aarch64.deb", 200, 2, "2a01:111:f400::1"),
            groupe("/termux/pool/bonk_0.1.6_aarch64.deb", 200, 1, "2001:db8::5"),
        ], RUNNERS)
        self.assertEqual((comptes["all"]["script"], comptes["devices"]["script"]), (34, 4))
        self.assertEqual((comptes["all"]["termux"], comptes["devices"]["termux"]), (3, 1))


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
            ancien = dict.fromkeys(compteurs.CANAUX, 0) | {"apt": 900, "homebrew": 4}
            (dossier / "jours" / "2026-11-28.json").write_text(json.dumps(ancien))
            tous = dict.fromkeys(compteurs.CANAUX, 0) | {"apt": 450, "homebrew": 1}
            appareils = dict.fromkeys(compteurs.CANAUX, 0) | {"apt": 300}
            jour = {"all": tous, "devices": appareils}
            (dossier / "jours" / "2026-11-29.json").write_text(json.dumps(jour))
            github = {"bonk-0.1.6-windows-x86_64-setup.exe": 30, "bonk-cli-0.1.6-linux-x86_64.tar.gz": 20}
            resume = compteurs.ecrire_totaux(dossier, github)
            self.assertEqual(resume["counted_until"], "2026-11-29")
            self.assertEqual((resume["github"]["total"], resume["repositories"], resume["total"]), (50, 1350, 1400))
            self.assertEqual(resume["channels"]["homebrew"], 5)
            self.assertEqual((resume["devices"]["total"], resume["devices"]["apt"]), (1204, 1200))
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
