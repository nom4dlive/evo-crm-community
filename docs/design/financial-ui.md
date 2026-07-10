# Design Document: Financial Management UI (Phase 3)

Este documento define a especificação visual e estrutural das telas e componentes do módulo financeiro para superadmin e inquilino.

---

## 1. Cores e Tipografia (Design Tokens)
- **Tema Geral**: Suporte nativo a Dark Mode (padrão) e Light Mode baseado em classes Tailwind CSS v4.
- **Tipografia**: Família `Inter` ou padrão do sistema, tamanhos `sm` para dados, `base` para textos gerais e `lg/xl/2xl` para cabeçalhos e KPI Cards.
- **Paleta de Cores**:
  - *Destaque/Ações*: Violeta (`bg-violet-600` / `hover:bg-violet-700`)
  - *Sucesso/Ativo/Pago*: Esmeralda (`text-emerald-500` / `bg-emerald-500/10`)
  - *Aviso/Trial*: Âmbar (`text-amber-500` / `bg-amber-500/10`)
  - *Erro/Past Due*: Vermelho (`text-red-500` / `bg-red-500/10`)
  - *Neutro/Cancelado/Inativo*: Slate/Cinza (`text-slate-500` / `bg-slate-500/10`)

---

## 2. Layouts das Telas

### A. Superadmin: Gestão de Planos (`/financial/plans`)
- **Tabela de Planos**:
  - Colunas: Nome do Plano, Tier (Starter/Pro/Enterprise), Preço Mensal (BRL), Preço Anual (BRL), Status (Badge ativo/inativo) e Ações (Editar, Ativar/Desativar).
- **Modais de Ação**:
  - Modal "Criar Plano": Form com inputs validados para `name`, `tier` (select), `price_monthly` (number), `price_annual` (number), `limit_instances` (number), `limit_agents` (number), `limit_messages_per_month` (number).
  - Modal "Editar Plano": Mesmo formulário carregado com os dados existentes.

### B. Superadmin: Todas as Assinaturas (`/financial/subscriptions`)
- **Tabela de Assinaturas**:
  - Colunas: Tenant (Nome da Conta), Plano Atual, Ciclo (Mensal/Anual), Status (Badge colorida), Data de Renovação.
  - Filtro: Select de status no cabeçalho (Todos, Ativas, Trial, Atrasadas, Canceladas).
  - Paginação: Controles de anterior/próximo e tamanho de página.

### C. Superadmin: MRR Dashboard (`/financial/dashboard`)
- **KPI Cards Grid**:
  - **MRR Card**: Valor acumulado formatado em BRL (`R$ X.XXX,XX`) com ícone de receita.
  - **Churn Card**: Contagem de cancelamentos no mês corrente com sinalizador de tendência.
  - **Overdue Card**: Contagem de inadimplentes (status `past_due`) na cor vermelha de alerta.
- **Gráfico de Receita**:
  - Gráfico de área (AreaChart) usando Recharts, com preenchimento em gradiente violeta esmeralda (`stroke-violet-500`, `fill-url(#colorRevenue)`) exibindo a evolução da receita coletada nos últimos 12 meses.

### D. Inquilino Admin: Minha Assinatura (`/financial/subscription`)
- **Card de Assinatura Ativa**:
  - Exibe o plano contratado (ex: "Pro"), badge de status correspondente, preço, ciclo e data de renovação.
  - Botão "Alterar Plano" que exibe os outros planos ativos da plataforma para upgrade/downgrade.

### E. Inquilino Admin: Histórico de Faturas (`/financial/invoices`)
- **Tabela de Invoices**:
  - Número da Fatura, Vencimento, Valor total formatado, Status Badge (Pago, Aberto, Cancelado).
  - Botão "Download PDF" (link para a página de faturas hospedada do Asaas).

### F. Inquilino Admin: Cobranças de Contatos (`/financial/charges`)
- **Tabela de Cobranças**:
  - Cliente (Contato), Descrição, Valor, Vencimento, Método (PIX/Boleto/Cartão), Status.
  - Botão "Copiar Link" para cobranças pendentes.
- **Modal "Criar Cobrança"**:
  - Form com select de contatos (busca local), valor, vencimento, descrição e método de pagamento.
