**Roles**

id (UUID), name (String), pin **(String, 4 dígitos)**, is\_active (Bool)

Define los roles del sistema y almacena el PIN de acceso de cada uno.

**PaymentMethods**

id (UUID), name (String), requires\_bank (Bool), requires\_reference (Bool), is\_active (Bool)

Catálogo dinámico de métodos de pago (Pago Móvil, POS, Efectivo, etc.).

**ExchangeRate**

id (UUID), rate (Double), created\_at (DateTime), created\_by\_role\_id (UUID)

Historial de tasas. Registra qué rol (usualmente Encargada) hizo el cambio.

**Categories**

id (UUID), name (String), is\_active (Bool)

Clasificación del menú (ej. Bebidas, Comida).

**Products**

id (UUID), category\_id (UUID), name (String), price\_usd (Double), is\_available (Bool)

Relacionado a Categories. Precio base en dólares.

**Orders**

id (UUID), created\_by\_role\_id (UUID), status (String), total\_usd (Double), exchange\_rate\_id (UUID)

Cabecera del pedido. Guarda la tasa exacta usada y qué rol creó la orden.

**OrderItems**

id (UUID), order\_id (UUID), product\_id (UUID), qty (Int), unit\_price\_usd (Double)

Detalle de los productos dentro de la orden.

**Payments**

id (UUID), order\_id (UUID), payment\_method\_id (UUID), amount\_usd (Double), amount\_ves (Double), reference (String, opcional), bank (String, opcional), status (String)

Relacionado a PaymentMethods. Registra el pago y su estado (pendiente o aprobado).