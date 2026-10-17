# ruby_doom

![DOOM rodando em Ruby com SDL2](screenshot/doom.png)

**Vídeo:** [DOOM rodando em Ruby](https://youtu.be/h8wSVxCc_9g)

**Repositório:** [github.com/vagucs/rudy_doom](https://github.com/vagucs/rudy_doom)

DOOM generic portado de **[python_doom](https://github.com/vagucs/python_doom)** para **Ruby 3.4 + SDL2**.

Por **Wagner Nunes da Silva**

- vagucs@bol.com.br
- vagucs@vagucs.com.br
- vagucs@gmail.com
- [www.vagucs.com.br](https://www.vagucs.com.br)
- [LinkedIn](https://www.linkedin.com/in/wagner-nunes-da-silva-b0a15360)

English version: [README.md](README.md)

---

## O que é este projeto

`python_doom` é um motor de DOOM condensado e jogável, em Python. Este diretório começa a **mesma peça de estudo**, em Ruby:

- Janela e teclas: **SDL2**, chamada pela gem `ffi`. O motor não entra nessa ponte
- Framebuffer: 320×200, esticado numa janela de 640×400
- Ponto fixo 16.16: `lib/doom/compat.rb`, a mesma conta de `doom/compat.py`. O inteiro do Ruby cresce sozinho, e o `>>` preenche com o sinal
- IWAD: `lib/doom/wad.rb`

É preciso um IWAD legal (shareware `doom1.wad` ou comercial `doom.wad` / `doom2.wad`). Este repositório não traz WAD comercial.

---

## Proposta educacional

O port em Python já tirou o pré-processador e os arrays 1-based do Harbour. O port em Ruby pergunta o que muda quando o inteiro cresce sozinho e o `>>` preenche com o sinal, sem arquivo C.

- **Python, depois Ruby.** Abra `python_doom/doom/` ao lado de `ruby_doom/lib/doom/`.
- **Estouro escrito.** `as_i32` devolve o produto 16.16 para 32 bits.
- **Onde o Ruby basta.** O diretório do WAD, o patch e o laço ficam em Ruby. A SDL2 é a janela.

---

## De Python para Ruby

| Python (`python_doom`) | Ruby (`ruby_doom`) |
| --- | --- |
| `thing.x` | `thing.x` |
| `None` | `nil` |
| `items[0]` | `items[0]` |
| classe | `class` |
| `int` sem limite | `Integer` sem limite; `as_i32` corta em 32 |
| `//` | `/` em inteiros, que também arredonda para baixo |
| framebuffer `bytearray` | string binária |
| pygame | SDL2 pela gem `ffi` |

---

## Tecnologia

| Camada | Este port | Python (`python_doom`) |
| --- | --- | --- |
| Linguagem | Ruby 3.4, `C:\Ruby34-x64\bin\ruby.exe` | Python 3.10+ |
| Janela | SDL2, gem `ffi` | pygame 2.x |
| Ponto fixo 16.16 | `lib/doom/compat.rb` | `doom/compat.py` |
| IWAD | `lib/doom/wad.rb` | `doom/wad.py` |

---

## Como rodar

Neste diretório, no Windows:

```
run.bat
run.bat -fps
run.bat -iwad ..\DOOM1.WAD
```

`-iwad` escolhe o arquivo. Um caminho solto terminado em `.wad` também serve. `-warp` pula o título e abre o mapa. `-fps` mostra os quadros por segundo no canto superior direito. F11 liga e desliga esse contador. A busca começa em `DOOMWADDIR` ou `DOOMWADPATH`, e segue por esta pasta e pelas pastas acima. `lib/SDL2.dll` é a biblioteca de 64 bits que a gem `ffi` carrega.

---

## Teclas

| Tecla | Ação |
| --- | --- |
| **Enter** | Confirma o item do menu. No título, entra no mapa |
| **Seta esquerda / direita** | Virar |
| **Seta cima / baixo** | Andar. Shift corre |
| **Espaço** ou **E** | Abrir a porta à frente ou usar um interruptor |
| **Ctrl** | Disparar a arma da mão |
| **1** a **7** | Trocar a arma |
| **Tab** | Abre e fecha o mapa |
| **- / +** | Tamanho da área de jogo dentro da janela |
| **F11** | Liga e desliga o contador de quadros |
| **Esc** | Abre o menu |
| **Alt+Enter** | Tela cheia |
| **Alt** | Andar de lado |
| **, / .** | Passo lateral |
| **Mouse** | Virar e olhar. Botão dispara |
| **Pause** | Pausa |
| Fechar a janela | Sair |

---

## Linhagem

1. **[python_doom](https://github.com/vagucs/python_doom)** — Python + pygame
2. **[rudy_doom](https://github.com/vagucs/rudy_doom)** — Ruby 3.4 + SDL2 (esta árvore)

---

## Doe

### Patrocínio no GitHub

[github.com/sponsors/vagucs](https://github.com/sponsors/vagucs)

### Ethereum

`0x1b64038A2b1DB73ABd0068d8B9B0d1dC5a90C5F1`

![QR Code Ethereum](docs/qr-ethereum.png)

### PIX

Chave: `vagucs@bol.com.br`

![QR Code PIX](docs/qr-pix.png)
