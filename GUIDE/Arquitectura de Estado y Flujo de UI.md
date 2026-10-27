**Flujo de Navegación (Router)**

**AuthScreen (Login):** Teclado numérico (Grid) de 4 dígitos. Al ingresar el PIN, el sistema evalúa el role y redirige.

**Enrutamiento por Rol:**

**Cajera -> POS\_Screen:** Pantalla principal de ventas.

**Cocinero -> KDS\_Screen:** Pantalla de cola de comandas.

**Encargada -> Admin\_Dashboard\_Screen:** Panel de gestión.

**Gestores de Estado Principales (Providers)**

**authProvider:** Almacena el usuario logueado actualmente y su rol.

**exchangeRateProvider:** Escucha la tasa activa. Cualquier cambio actualiza automáticamente los precios en Bolívares en toda la app.

**cartProvider:** Un estado inmutable (lista de OrderItems) que maneja la lógica de agregar, restar cantidad y vaciar el carrito. Calcula los totales multiplicando por el exchangeRateProvider.

**ordersProvider:** Escucha los cambios en la tabla Orders para actualizar en tiempo real el KDS de la cocina.