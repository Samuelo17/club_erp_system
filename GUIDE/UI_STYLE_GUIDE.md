# Guía de Estilo UI/UX - Sistema POS (Club ERP)

Este documento define las reglas de diseño visual y de experiencia de usuario (UX) para la aplicación. Cualquier agente de IA generador de código o desarrollador debe adherirse estrictamente a estos lineamientos para mantener la consistencia en todos los módulos (POS, Cocina, Admin).

## 1. Filosofía de Diseño
El diseño está optimizado para operaciones rápidas en pantallas táctiles (tablets/monitores horizontales). La interfaz debe ser limpia, moderna y minimizar la fatiga visual. Se prioriza la legibilidad y los botones grandes para evitar toques accidentales en horas pico[cite: 2].

## 2. Paleta de Colores
*   **Fondos (Backgrounds):** Se utiliza un fondo gris muy claro o blanco humo para el lienzo principal, y blanco puro (`#FFFFFF`) para las tarjetas (Cards) y paneles[cite: 1, 2].
*   **Color Primario (Acento):** **Naranja Vibrante**. Es el color clave de la aplicación. Se utiliza para botones de acción principales (ej. "EMITIR COMANDA Y COBRAR"), pestañas activas, barras de progreso y gráficos principales[cite: 1, 2].
*   **Textos:** Negro para títulos y gris oscuro para descripciones o textos secundarios[cite: 1, 2].
*   **Colores Semánticos (Estados):**
    *   **Verde:** Éxito, métricas de "Estado Óptimo", y tickets de cocina "ENTREGADO AL MOZO" o "PASE LISTO"[cite: 1, 3].
    *   **Rojo/Rosado:** Alertas críticas, productos agotados ("86 AGOTADO"), mermas, y pedidos fuertemente demorados[cite: 1, 3].
    *   **Morado Claro:** Órdenes nuevas entrantes[cite: 3].

## 3. Tipografía
*   Debe usarse una fuente Sans-Serif moderna, limpia y geométrica (ej. *Inter*, *Roboto* o *Poppins*).
*   Los precios, métricas clave y números de mesa deben tener un tamaño de fuente grande y un peso en negrita (Bold o SemiBold) para una lectura instantánea a distancia[cite: 1, 2].

## 4. Estructura de Pantallas (Layouts)

### A. Terminal de Cobro (POS)
Layout dividido horizontalmente[cite: 2]:
*   **Menú Lateral (Sidebar):** Minimalista a la izquierda, solo con íconos para cambiar entre módulos (Terminal, Cocina, Admin)[cite: 2].
*   **Panel Izquierdo (~70%):** Área de catálogo. Contiene una barra de búsqueda superior, un menú horizontal deslizable de categorías (Chips con bordes redondeados) y un `GridView` de productos. Las tarjetas de productos son blancas, con sombras sutiles, precio y controles táctiles `+`[cite: 2].
*   **Panel Derecho (~30%):** El Ticket/Carrito de compras. Fondo blanco que destaca sobre el gris del fondo. Contiene la lista de ítems, el subtotal, un selector de métodos de pago y un botón de cobro gigante de color Naranja anclado en la parte inferior[cite: 2].

### B. Cocina (KDS - Kitchen Display System)
Layout tipo Kanban[cite: 3]:
*   **Área de Tickets:** Una cuadrícula de tarjetas (Cards) que representan los pedidos. Cada tarjeta incluye un temporizador visible y controles tipo "Checklist" para marcar los platos listos[cite: 3].
*   **Codificación Visual:** Todo el borde exterior y los botones de la tarjeta cambian de color según el estado del pedido (Morado: Nuevo, Rojo: Demorado, Naranja: En preparación, Verde: Listo)[cite: 3].
*   **Panel Lateral:** Un panel de "Control de Stock" con interruptores (switches) tipo *Toggle* para bloquear ventas de ingredientes agotados en tiempo real[cite: 3].

### C. Panel Gerencial (Admin Dashboard)
Layout de tableros analíticos[cite: 1]:
*   Uso de tarjetas (Cards) distribuidas en columnas para mostrar KPIs (Ventas, Afluencia, Tiempos)[cite: 1].
*   Integración de gráficos de barras simples utilizando el color naranja y picos críticos[cite: 1].

## 5. Geometría y Componentes (Código Flutter)
*   **Bordes Redondeados (`borderRadius`):** Absolutamente todos los componentes (tarjetas, botones, chips de filtro, barras de búsqueda) deben tener esquinas redondeadas (aprox. `8.0` a `12.0` de radio) para un look amigable[cite: 1, 2, 3]. Evitar esquinas afiladas a 90 grados.
*   **Sombras (`boxShadow`):** Las tarjetas y paneles flotantes deben tener una sombra muy suave y difuminada hacia abajo para separarlas del fondo y dar jerarquía visual[cite: 1, 2, 3].
*   **Botones Ergonómicos:** Los botones de "Más/Menos" cantidades y los botones de cobro deben ser amplios para ser pulsados fácilmente con el dedo sin requerir precisión milimétrica[cite: 2].