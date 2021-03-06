# Odoo Install script for Ubuntu servers

[![ShellCheck](https://github.com/engineervix/ubuntu-odoo-setup/actions/workflows/main.yml/badge.svg)](https://github.com/engineervix/ubuntu-odoo-setup/actions/workflows/main.yml)
![GitHub last commit](https://img.shields.io/github/last-commit/engineervix/ubuntu-odoo-setup)
![GitHub commits since latest release (by SemVer)](https://img.shields.io/github/commits-since/engineervix/ubuntu-odoo-setup/latest/main)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![License : MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Introduction ✨

This script builds on top of [Yenthe Van Ginneken's excellent and well known Odoo Install Script](https://github.com/Yenthe666/InstallScript) to make it easy and painless to setup [Odoo](https://www.odoo.com/) on a server bootstrapped using <https://github.com/engineervix/ubuntu-server-setup>

> It's only been tested with Odoo 15.0 on Ubuntu 20.04

## Usage 🚀

- First things first, this script **assumes** that your Ubuntu server has been setup using
  <https://github.com/engineervix/ubuntu-server-setup>. If this is the case ... proceed ...
- download the script from GitHub:

  ```bash
  wget https://github.com/engineervix/ubuntu-odoo-setup/raw/main/odoo_install.sh
  ```

- make your own modifications if you wish to change some things
- ensure that it's executable:

  ```bash
  chmod +x odoo_install.sh
  ```

- run the script to install Odoo:

  ```bash
  ./odoo_install.sh
  ```

## How is this script different from Yenthe VG's? 🖥️

The main difference is that we already have a server that's been setup with a custom user,
Nginx, certbot, PostgreSQL, Node.js, etc. So we don't wanna install these things. Further:

- we'd like to use a **virtual environment** to run Odoo
- we wanna use **Systemd** and not **init**
- this isn't a comprehensive script that covers multiple Odoo versions and Ubuntu versions (it's only been tested with Odoo 15.0 / Ubuntu 20.04. If you have other needs, please feel free to fork and customize)

## References

- [Odoo 15.0 Docs](https://www.odoo.com/documentation/15.0/administration/install/install.htm)
- [Install and Deploy Odoo 15 from source on DigitalOcean](https://codingdodo.com/install-and-deploy-odoo-15-from-source-on-digitalocean/)
- [How to Install Odoo 15 on Ubuntu 20.04 (linuxize.com)](https://linuxize.com/post/how-to-install-odoo-15-on-ubuntu-20-04/)
- [How to Install Odoo 15 on Ubuntu 20.04 (speedysense.com)](https://speedysense.com/install-odoo-15-on-ubuntu-20-04/)
- [How to Install Odoo on Ubuntu](https://phoenixnap.com/kb/install-odoo-ubuntu)

## Author

👤 **Victor Miti**

- Blog: <https://importthis.tech>
- Twitter: [![Twitter: engineervix](https://img.shields.io/twitter/follow/engineervix.svg?style=social)](https://twitter.com/engineervix)
- Github: [@engineervix](https://github.com/engineervix)

## Contributing 🤝

Contributions, issues and feature requests are most welcome!

Feel free to check the [issues page](https://github.com/engineervix/ubuntu-odoo-setup/issues) and take a look at the [contributing guide](CONTRIBUTING.md) before you get started

## Show your support

Please give a ⭐️ if you found this project helpful!

## License 📝

Copyright for portions of [@engineervix/ubuntu-odoo-setup](https://github.com/engineervix/ubuntu-odoo-setup) are held by Yenthe V.G, © 2018 as part of [@Yenthe666/InstallScript](https://github.com/Yenthe666/InstallScript). All other copyright for [@engineervix/ubuntu-odoo-setup](https://github.com/engineervix/ubuntu-odoo-setup) are held by [Victor Miti](https://github.com/engineervix), © 2022.

This project is licensed under the terms of the [MIT](https://github.com/engineervix/ubuntu-odoo-setup/blob/main/LICENSE) license.
