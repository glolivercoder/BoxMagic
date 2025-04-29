# MAGIC CAPTURE Button — Documentação Técnica

Este documento descreve o funcionamento do botão "MAGIC CAPTURE" na tela "Adicionar Novo Item" do sistema LinkVendas Express. O recurso permite capturar informações de produtos a partir de imagens, utilizando IA generativa Gemini e OCR.

---

## 1. Exemplo de Uso do Componente

```jsx
import MagicCaptureButton from './components/MagicCaptureButton';

<MagicCaptureButton onProductDataExtracted={dados => {
  // Utilize os dados extraídos (nome, preço, etc.)
}} />
```

---

## 2. Fluxo de Funcionamento

1. **Usuário clica em MAGIC CAPTURE**
2. Um seletor é exibido para escolher entre câmera ou galeria.
3. Após seleção/captura, a imagem é processada:
   - OCR (Tesseract.js) extrai o texto.
   - A imagem é convertida para base64.
   - Um prompt é enviado para a API Gemini (Google Generative AI), junto com o texto extraído.
4. O Gemini retorna um JSON estruturado com os campos identificados.
5. Os dados extraídos são enviados para o callback `onProductDataExtracted`.

---

## 3. Exemplo de Prompt Usado

```
Analise esta imagem de um documento e me retorne um JSON com os campos encontrados.
Identifique os seguintes campos específicos:
- Nome Completo
- CPF
- RG
- Data de Expedição
- Data de Nascimento
- Naturalidade
- Filiação (Nome do Pai e Nome da Mãe)

Considere também o texto extraído por OCR: <texto extraído>
```

---

## 4. API Gemini Utilizada

- **Biblioteca:** `@google/generative-ai`
- **Chave:** `VITE_GEMINI_API_KEY` (configuração em ambiente)
- **Modelo:** `gemini-1.5-flash` (ou definido em `VITE_GEMINI_MODEL`)
- **Configuração:**
  - temperature: 0.1
  - topK: 1
  - topP: 1
  - maxOutputTokens: 2048

---

## 5. Principais Arquivos Relacionados

- `src/components/MagicCaptureButton.jsx` — Interface do botão e fluxo de captura.
- `src/services/GeminiService.js` — Serviço de integração com Gemini e OCR.

---

## 6. Observações

- O prompt e a extração podem ser adaptados conforme o tipo de documento/produto.
- O arquivo não excede 4000 tokens.
- Para funcionamento, configure as variáveis de ambiente Gemini corretamente.

---

> Dúvidas ou melhorias? Consulte o código-fonte ou entre em contato com o responsável técnico.
