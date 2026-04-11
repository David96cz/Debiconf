#!/usr/bin/env python3
import sys
import glob
import os
import subprocess
import shutil
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QTabWidget, QLabel, QLineEdit, 
                             QPushButton, QCheckBox, QComboBox, QFileDialog, 
                             QListWidget, QListWidgetItem, QMessageBox, QGroupBox, QFormLayout)
from PyQt5.QtCore import Qt, QFileInfo

# --- KONFIGURACE ---
# Cesty se automaticky přizpůsobí domovské složce uživatele
USER_HOME = os.path.expanduser("~")
APPS_DIR = os.path.join(USER_HOME, ".local/share/applications")
BUSY_SCRIPT = os.path.join(USER_HOME, ".local/bin/busy-launch.py")

# Standardní XDG Kategorie pro LXQt menu
XDG_CATEGORIES = [
    ("🎮 Hry", "Game"),
    ("🌍 Internet", "Network"),
    ("🎨 Grafika", "Graphics"),
    ("💼 Kancelář", "Office"),
    ("🎬 Zvuk a Video", "AudioVideo"),
    ("🛠️  Systémové nástroje", "System;Utility"),
    ("💻 Vývoj", "Development"),
    ("🎒 Příslušenství", "Qt;Utility")
]

class ShortcutApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Správce Zástupců (Debiconf LXQt)")
        self.resize(650, 550)
        
        # Hlavní widget a taby
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)
        
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)
        
        # Inicializace tabů
        self.init_creator_tab()
        self.init_manager_tab()
        
    def init_creator_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        form_group = QGroupBox("Vytvořit nového zástupce")
        form_layout = QFormLayout(form_group)
        
        # 1. Název
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("Např: Moje Hra")
        self.name_input.textChanged.connect(self.update_auto_comment)
        form_layout.addRow("Název aplikace:", self.name_input)
        
        # 2. Komentář
        self.comment_input = QLineEdit()
        self.comment_input.setEnabled(False) # Výchozí stav (šedé)
        
        self.auto_comment_cb = QCheckBox("Automatický")
        self.auto_comment_cb.setChecked(True)
        self.auto_comment_cb.stateChanged.connect(self.toggle_comment_mode)
        
        comment_layout = QHBoxLayout()
        comment_layout.addWidget(self.comment_input)
        comment_layout.addWidget(self.auto_comment_cb)
        form_layout.addRow("Popis (Komentář):", comment_layout)
        
        # 3. Příkaz / Cesta k souboru
        self.exec_input = QLineEdit()
        self.exec_input.setPlaceholderText("Cesta k .exe, .sh nebo příkaz")
        self.exec_input.textChanged.connect(self.validate_exec_intelligence)
        self.exec_btn = QPushButton("Procházet...")
        self.exec_btn.clicked.connect(self.pick_exec_file)
        
        exec_layout = QHBoxLayout()
        exec_layout.addWidget(self.exec_input)
        exec_layout.addWidget(self.exec_btn)
        form_layout.addRow("Příkaz / Cesta (Povinné):", exec_layout)
        
        # --- INTELIGENTNÍ VOLBY (Skryté v základu) ---
        self.intel_group = QGroupBox("Inteligentní nastavení")
        intel_layout = QVBoxLayout(self.intel_group)
        self.terminal_cb = QCheckBox("Spustit v terminálu")
        self.wrapper_cb = QCheckBox("Použít Python Wrapper (proti zamrzání)")
        self.wrapper_cb.setChecked(True)
        intel_layout.addWidget(self.terminal_cb)
        intel_layout.addWidget(self.wrapper_cb)
        self.intel_group.hide() # Skryjeme, dokud není detekován typ
        form_layout.addRow(self.intel_group)
        
        # 4. Kategorie (OPRAVA: Přidáno menu)
        self.category_input = QComboBox()
        for friendly_name, xdg_name in XDG_CATEGORIES:
            self.category_input.addItem(friendly_name, xdg_name)
        form_layout.addRow("Kategorie menu:", self.category_input)
        
        # 5. Ikona
        self.icon_input = QLineEdit()
        self.icon_btn = QPushButton("Vybrat...")
        self.icon_btn.clicked.connect(self.pick_icon_file)
        self.extract_btn = QPushButton("Vytáhnout z EXE")
        self.extract_btn.clicked.connect(self.extract_exe_icon)
        self.extract_btn.hide() # Skryté, dokud není detekován EXE
        
        icon_layout = QHBoxLayout()
        icon_layout.addWidget(self.icon_input)
        icon_layout.addWidget(self.icon_btn)
        icon_layout.addWidget(self.extract_btn)
        form_layout.addRow("Ikona aplikace:", icon_layout)
        
        # 6. Tlačítko Vytvořit
        self.create_btn = QPushButton("Vytvořit zástupce v Menu")
        self.create_btn.setStyleSheet("font-weight: bold; padding: 12px; background-color: #2a7fca; color: white;")
        self.create_btn.clicked.connect(self.create_shortcut)
        
        layout.addWidget(form_group)
        layout.addStretch() # Vytlačí tlačítko dolů
        layout.addWidget(self.create_btn)
        self.tabs.addTab(tab, "Generátor")

    def init_manager_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # Vyhledávání
        self.search_bar = QLineEdit()
        self.search_bar.setPlaceholderText("Hledat aplikaci v místním menu...")
        self.search_bar.textChanged.connect(self.filter_apps)
        layout.addWidget(self.search_bar)
        
        # Seznam aplikací
        self.app_list = QListWidget()
        layout.addWidget(self.app_list)
        
        # Tlačítka pro správu
        button_layout = QHBoxLayout()
        self.save_btn = QPushButton("Uložit viditelnost")
        self.save_btn.setStyleSheet("background-color: #4caf50; color: white;")
        self.save_btn.clicked.connect(self.save_visibility)
        
        self.delete_btn = QPushButton("Smazat zástupce")
        self.delete_btn.setStyleSheet("background-color: #f44336; color: white;")
        self.delete_btn.clicked.connect(self.delete_shortcut)
        
        button_layout.addWidget(self.save_btn)
        button_layout.addWidget(self.delete_btn)
        layout.addLayout(button_layout)
        
        self.tabs.addTab(tab, "Správce zobrazení")
        self.load_applications()

    # --- POMOCNÉ FUNKCE ---
    def refresh_system_menu(self):
        """Upozorní systém na změny a restartuje panel pro okamžitý efekt."""
        # 1. Update databáze zástupců (standardní krok)
        subprocess.run(["update-desktop-database", APPS_DIR], capture_output=True)
        # 2. Agresivní restart LXQt panelu (OPRAVA: Okamžitý efekt)
        subprocess.run(["lxqt-panel", "--restart"], capture_output=True)
        log_msg = "Systémové menu bylo aktualizováno."
        print(log_msg)

    # --- LOGIKA GENERÁTORU ---
    def toggle_comment_mode(self):
        is_auto = self.auto_comment_cb.isChecked()
        self.comment_input.setEnabled(not is_auto)
        if is_auto:
            self.update_auto_comment()

    def update_auto_comment(self):
        if self.auto_comment_cb.isChecked():
            self.comment_input.setText(f"Spustit {self.name_input.text()}")

    def pick_exec_file(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Vyber spustitelný soubor", USER_HOME, "All (*);;Executables (*.exe *.sh)")
        if fname:
            self.exec_input.setText(fname)

    def validate_exec_intelligence(self, text):
        """Automaticky nastavuje volby a zamyká nesmysly podle přípony."""
        path = text.strip()
        if not path:
            self.intel_group.hide()
            self.extract_btn.hide()
            return

        self.intel_group.show()
        info = QFileInfo(path)
        suffix = info.suffix().lower()

        if suffix == 'exe':
            self.terminal_cb.setChecked(False)
            self.terminal_cb.setEnabled(False) # ZAKÁŽE terminál (bude šedý)
            self.wrapper_cb.setChecked(True)
            self.extract_btn.show()
        elif suffix == 'sh':
            self.terminal_cb.setChecked(True)
            self.terminal_cb.setEnabled(True) # POVOLÍ terminál
            self.wrapper_cb.setChecked(False)
            self.extract_btn.hide()
        else:
            self.terminal_cb.setEnabled(True)
            self.extract_btn.hide()

    def extract_exe_icon(self):
        """Ostrá logika pro vytažení ikony přes icoutils."""
        exe_path = self.exec_input.text()
        
        # Kontrola, jestli máme nástroje
        wrestool_check = shutil.which("wrestool")
        if not wrestool_check:
            QMessageBox.critical(self, "Chybí závislosti", "Nemáš nainstalovaný balíček 'icoutils' (sudo apt install icoutils).\nExtrakce není možná.")
            return

        info = QFileInfo(exe_path)
        name_no_ext = info.baseName()
        target_dir = info.absolutePath()
        
        tmp_ico = f"/tmp/{name_no_ext}.ico"
        tmp_icons_dir = f"/tmp/{name_no_ext}_icons"
        
        try:
            # 1. Krok: Vytažení .ico z .exe přes wrestool
            with open(tmp_ico, "w") as f:
                subprocess.run(["wrestool", "-x", "-t", "14", exe_path], stdout=f, stderr=subprocess.DEVNULL)
            
            if os.path.exists(tmp_ico) and os.path.getsize(tmp_ico) > 0:
                # 2. Krok: Rozsekání .ico na .png obrázky přes icotool
                os.makedirs(tmp_icons_dir, exist_ok=True)
                subprocess.run(["icotool", "-x", tmp_ico, "-o", tmp_icons_dir], stderr=subprocess.DEVNULL)
                
                # 3. Krok: Najdeme ten největší PNG (nejlepší kvalita)
                pngs = glob.glob(f"{tmp_icons_dir}/*.png")
                if pngs:
                    biggest_png = max(pngs, key=os.path.getsize)
                    target_icon = os.path.join(target_dir, f"{name_no_ext}.png")
                    
                    # Překopírujeme ho do složky k EXE souboru
                    shutil.copy(biggest_png, target_icon)
                    
                    # Automaticky vložíme cestu do políčka
                    self.icon_input.setText(target_icon)
                    QMessageBox.information(self, "Úspěch", f"Ikona byla úspěšně vytažena a uložena jako:\n{target_icon}")
                else:
                    QMessageBox.warning(self, "Chyba", "Nepodařilo se vygenerovat PNG obrázky z ikony.")
            else:
                QMessageBox.warning(self, "Chyba", "V tomto EXE souboru nebyla nalezena žádná ikona.")
                
        except Exception as e:
            QMessageBox.critical(self, "Chyba extrakce", f"Něco se podělalo:\n{str(e)}")
        finally:
            # Úklid bordelu v /tmp
            if os.path.exists(tmp_ico): 
                os.remove(tmp_ico)
            if os.path.exists(tmp_icons_dir): 
                shutil.rmtree(tmp_icons_dir)

    def pick_icon_file(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Vyber ikonu", "/usr/share/icons", "Images (*.png *.svg *.xpm *.ico)")
        if fname:
            self.icon_input.setText(fname)

    def create_shortcut(self):
        # 1. Validace povinných polí (OPRAVA: Přidána kontrola Exec)
        name = self.name_input.text().strip()
        exec_path = self.exec_input.text().strip()
        
        if not name:
            QMessageBox.warning(self, "Validace", "Název aplikace nesmí být prázdný!")
            return
        if not exec_path:
            QMessageBox.warning(self, "Validace", "Příkaz nebo Cesta k souboru nesmí být prázdná!")
            return

        # 2. Příprava dat
        comment = self.comment_input.text()
        # Získání XDG názvu kategorie
        category = self.category_input.currentData()
        icon = self.icon_input.text().strip() or "applications-other"
        terminal = "true" if self.terminal_cb.isChecked() else "false"
        
        # Bezpečný název souboru
        safe_name = "".join([c for c in name if c.isalpha() or c.isdigit() or c==' ']).rstrip()
        safe_name = safe_name.replace(' ', '-').lower()
        file_name = f"{safe_name}.desktop"
        output_file = os.path.join(APPS_DIR, file_name)

        # 3. Sestavení příkazu (Wine vs Wrapper vs Normal)
        final_exec = exec_path
        if exec_path.lower().endswith('.exe') and not exec_path.lower().startswith('wine'):
            final_exec = f"wine \"{exec_path}\""
        
        if self.wrapper_cb.isChecked():
            final_exec = f"python3 \"{BUSY_SCRIPT}\" {final_exec}"

        # 4. Zápis .desktop souboru
        try:
            if not os.path.exists(APPS_DIR):
                os.makedirs(APPS_DIR)
                
            with open(output_file, 'w') as f:
                f.write("[Desktop Entry]\n")
                f.write("Version=1.0\n")
                f.write("Type=Application\n")
                f.write(f"Name={name}\n")
                f.write(f"Comment={comment}\n")
                f.write(f"Exec={final_exec}\n")
                f.write(f"Icon={icon}\n")
                # Nastavení pracovního adresáře, pokud je to cesta
                info = QFileInfo(exec_path)
                if info.exists() and info.isFile():
                    f.write(f"Path={info.absolutePath()}\n")
                f.write(f"Categories={category};\n")
                f.write(f"Terminal={terminal}\n")
                f.write("StartupNotify=false\n")
            
            os.chmod(output_file, 0o755)
            # Okamžitá aktualizace (OPRAVA: Volání funkce)
            self.refresh_system_menu()
            
            QMessageBox.information(self, "Hotovo", f"Zástupce '{name}' byl vytvořen a přidán do menu.")
            # Reset formuláře
            self.name_input.clear()
            self.exec_input.clear()
            self.icon_input.clear()
            self.load_applications() # Refresh seznamu ve správci

        except Exception as e:
            QMessageBox.critical(self, "Chyba", f"Nepodařilo se zapsat soubor:\n{str(e)}")

    # --- LOGIKA SPRÁVCE ---
    def load_applications(self):
        self.app_list.clear()
        if not os.path.exists(APPS_DIR):
            return
            
        for filename in os.listdir(APPS_DIR):
            if filename.endswith(".desktop"):
                filepath = os.path.join(APPS_DIR, filename)
                # Zjednodušená detekce NoDisplay
                is_hidden = False
                try:
                    with open(filepath, 'r', errors='ignore') as f:
                        content = f.read()
                        if "NoDisplay=true" in content:
                            is_hidden = True
                except: continue
                
                item = QListWidgetItem(filename)
                item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
                item.setCheckState(Qt.Unchecked if is_hidden else Qt.Checked)
                item.setData(Qt.UserRole, filepath) 
                self.app_list.addItem(item)

    def filter_apps(self, text):
        for i in range(self.app_list.count()):
            item = self.app_list.item(i)
            item.setHidden(text.lower() not in item.text().lower())

    def save_visibility(self):
        for i in range(self.app_list.count()):
            item = self.app_list.item(i)
            filepath = item.data(Qt.UserRole)
            is_visible = (item.checkState() == Qt.Checked)
            
            try:
                with open(filepath, 'r', errors='ignore') as f:
                    lines = f.readlines()
                    
                with open(filepath, 'w') as f:
                    for line in lines:
                        if not line.startswith("NoDisplay="):
                            f.write(line)
                    if not is_visible:
                        f.write("NoDisplay=true\n")
            except: continue
                    
        # Okamžitá aktualizace (OPRAVA: Volání funkce)
        self.refresh_system_menu()
        QMessageBox.information(self, "Uloženo", "Změny byly uloženy a menu aktualizováno.")

    def delete_shortcut(self):
        current_item = self.app_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "Smazat", "Vyber zástupce ze seznamu, kterého chceš smazat.")
            return
            
        filename = current_item.text()
        filepath = current_item.data(Qt.UserRole)
        
        reply = QMessageBox.question(self, "Smazat zástupce", f"Opravdu chceš trvale smazat zástupce '{filename}'?", QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            try:
                os.remove(filepath)
                # Okamžitá aktualizace (OPRAVA: Volání funkce)
                self.refresh_system_menu()
                self.load_applications()
                QMessageBox.information(self, "Smazáno", f"Zástupce '{filename}' byl smazán.")
            except Exception as e:
                QMessageBox.critical(self, "Chyba", f"Nepodařilo se smazat soubor:\n{str(e)}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    # Nastavení stylu aplikace, aby lépe seděl do LXQt (pokud není detekován automaticky)
    app.setStyle("Fusion") 
    window = ShortcutApp()
    window.show()
    sys.exit(app.exec_())
