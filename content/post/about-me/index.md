---
date: '2026-10-09T14:27:00+08:00'
draft: false
lang: en
title: 'About Me'
---

## A short introduction to myself

<span style="font-size: 32px">**¡Hola!**</span> I am Joe, born and raised in Hong Kong, a software engineer now living with my partner and two lovely kitties 🐱🐱. 

![image](My_Cat_1.jpg)
*They are called **迅猛龍** (Raptor) and **霸王龍** (T-rex) from left to right.*

In weekend, we often go hiking ⛰️ and visit the beaches 🏖️ when the weather is good. People completely underestimate Hong Kong as a great place to hike. In reality, most of the territory is covered in lush greenery, and it is home to *25 country parks*. Like many of you, I love playing PC games, especially story-driven RPG and FPS, also a big fan of Japanese ACG Culture. Now, I am able to read original Japanese comics, anime and light novels (*still very slow*) without translation. However, I definitely need more practice to read Japanese fluently. Recently, I've been learning Spanish 🇪🇸 so that I can connect with the other half of the world!

> **Even if we don't share the same hobbies, I'm always happy to connect with fun people from all over the globe. You can find me [here](../contact-me) 😃.** 

Here are the best story-driven RPG I have ever played and always recommended to everyone:

- The Witcher 2 & 3 (Next Gen, Remastered not yet played) ⭐⭐⭐
- Portal 1 & 2 ⭐⭐⭐
- Portal Stories: Mel ⭐⭐⭐
- NieR: Automata
- NieR Replicant ver.1.22474487139 
- Half Life 1 & 2
- Grand Theft Auto V
- TitanFall 2
- Little Nightmares I & II

## Long story of my journey with Linux

I am proud to be an member of the [Arch Linux](https://archlinux.org/) and [KDE](https://kde.org/) communities. I feel like I have always had strong interest in technical stuff since I was a kid, like wanna to know about how things actually works, whether if I can do things differently when the underlying principle is the same, etc. These thoughts often spend me quite a lot of time to do research and experiments, but I would say it is **worth** for most of the time. 

I met Linux for the first time when I was in P5 (primary year 5, or called 5th grade in US). At that time, I was impressed by the UI design of Chrome OS, which had a semi-transparent windows and a file browser integrated with Google Drive natively. Meanwhile, the old home laptop with an Intel Atom CPU and [MS Windows XP](https://en.wikipedia.org/wiki/Windows_XP) installed was all I had. Therefore, I was finding way to replace the existing laptop OS with Chrome OS.  

That was lucky that there were a school TA who taught me to install [Chromium OS](https://www.chromium.org/chromium-os/developer-library/getting-started/) (Unofficial build as that time) to a USB stick, then boot with USB in one of the school computers. I will never forget the feeling I had at that moment when I saw [Tux](https://en.wikipedia.org/wiki/Tux_(mascot)) at the top of the screen with flickered boot log, followed by the Chromium OS setup wizard and the desktop, appeared in the school computer and my home laptop.  
As a fun fact, I reinstalled the OS three times just because I tried to log in to the tty as root, but no characters displayed when typing the password. I thought the OS was somehow broken, but it turned out to be expected behavior.

Starting from Chromium OS, I have used [Fedora](https://fedoraproject.org/) 20 with [Gnome](https://www.gnome.org/) 3, followed by [Debian](https://www.debian.org/) 8, finally Arch Linux to present. Of course, both of them are excellent Linux distributions, but with different philosophy. Among all of them, I find Arch Linux works best for me, as it always provides up-to-date packages through its rolling release model and simple management tools like `mkinitcpio`, `pacman`, and `makepkg`. Most importantly, it leaves plenty of room for me to customize the system architecture, e.g., the boot loader, file system layout, and exact package selection. These configuration is difficult or even impossible to change upon system installation.  
In my case, I usually place the root `/`, `home` and other common mounts to different `btrfs` subvolumes on top of a `luks2` encrypted partition. Therefore, all data is encrypted at rest and can be unlocked via TPM or a manually entered password during boot time.  

Unlike popular Linux distributions like Ubuntu and Fedora, where they usually provide GUI installers as official install approach, Arch Linux does not have any GUI installers, not even interactive text-based installer until recently, focusing user to configure the system manually with the instruction from the official [Installation guide](https://wiki.archlinux.org/title/Installation_guide).  

Initially, you will find missing packages, unsuccessful boot and strange system behaviors. Though repeatedly try-and-error steps, you will build the satisfying system as you want finally! As the result, you will be familiarized with the *how* the system is actually work, from the very first BIOS/EFI boot and boot loader, then early `initramfs` boot stage, followed by system services activation with `systemd`, after tty or graphical login screen, finally your favorite shell or desktop. This process builds my deep understanding to how modern operation system works. I would say the installation process and required manual configuration have been greatly simplified, thanks to the efforts of the open-source community.  

> **If you are interested in how operation system works, or even wanna to join our community, it is more than welcome to try out Arch Linux!**

I run Arch Linux in all my laptops and desktop computers with Windows installed for Windows-exclusive program. For server, I prefer Debian since it is solid as rock and seldom update system packages except for security patches. Running Linux in a customer hardware is usually unsupported for most manufacturers. This also means hardware compatibilities issues **including, but not limited to** higher battery consumption, missing drivers, bad sleep/awake due to buggy ACPI implementation and problematic hardware configuration.  

From my experience, most problems under Linux come from ACPI implementation as system firmware does not obey the standard 😡. In the case of laptop, some devices may need to use modified or dedicated driver, which is available only for Windows, to work properly. For instance, there were a buggy MaxxAudio-enabled Realtek audio device (*both Windows and Linux*) and a unusable fingerprint sensor (*under Linux, no driver*) in my previous Dell XPS 13 9305. <u>**Avoid any MaxxAudio-enabled devices at all cost**</u>.

With the years of development of the compatibility tool, like `wine` and its derived projects, most of the Windows-only games can be played in Linux environment without much efforts via [proton](https://github.com/valvesoftware/proton) provided by Steam client now. Still, many game mods and community patches are exclusive to Windows... In most cases, I can complete my work in the Arch Linux environment natively, except for licensed software like MS Office, which usually need to work inside a Windows VM.  

## Some thoughts on the world we live in...

As everyone know, It’s crazy how much Gen AI exploded over these three years (2023 to 2026). I feel like everything is being accelerated and changing rapidly. Not only the ways of the ways and threshold of acquiring knowledge, but also what people can do.  
Now, even you know nothing about data structures, algorithms, coding, you can simply build anything with few lines of prompts with an agent, click the button, review the generated plans, then wait for its result. All you need is to subscript a coding plan or pay up for your token usage. Many work which can be done by human previously, are being **automated** or even becoming the part of a large AI pipeline.  

In this situation, **Money that should be benefiting everyone is basically just going straight into the pockets of a few massive AI companies.** Eventually, no one will be able to afford the cost of living except for those with vested interests. This will definitely harm the long-term development of our society.

> **But before that day comes, I'm going to keep chasing my dreams and find my own place in the world!**
