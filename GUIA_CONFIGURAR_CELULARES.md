# 📖 Manual Definitivo de IT: Habilitar Grabación de Llamadas Nativa en Samsung (Método Legal)

Este documento es una guía paso a paso para el departamento de Sistemas/IT. Su propósito es vulnerar el bloqueo regional de grabación de llamadas que Google impone en equipos Samsung (Android 10 - 14) para lograr que la aplicación "Minuto a Minuto" pueda extraer el archivo de audio perfecto de la comunicación bidireccional entre el empleado y el cliente de forma inadvertida e ininterrumpida.

---

## 🛑 El Problema Tecnológico (Restricciones de Android)

A partir de Android 10, Google **bloqueó a nivel de núcleo (Kernel) el acceso al canal digital cerrado (Downlink/Uplink)** de las llamadas celulares para cualquier aplicación descargada (incluida la nuestra). 

**Consecuencia:** Si una aplicación intenta grabar la llamada por código, Android envía deliberadamente **cero bytes** de audio (silencio absoluto) de la voz de la otra persona. La única excepción a esta regla impuesta por Google es la propia **Aplicación de Teléfono Nativa del Fabricante** porque está firmada criptográficamente por Samsung.

**La Solución Estructural:** Modificar el código de región del software del celular de empresa (CSC) a un país donde las leyes locales exigen que la funcionalidad de grabar llamadas esté activa por defecto de fábrica.

---

## 🔧 El Método Eficaz: Cambio de CSC (Region) mediante SamFw Tool

Samsung no elimina el código fuente de su excelente grabadora nativa; simplemente lo oculta o bloquea en países específicos de América Latina. 

Este método cambiará el "pasaporte" de software del sistema a la región de **India (INS)** o **Vietnam (XXV)**.
> **Importante:** Este proceso **NO** elimina los datos del vendedor del teléfono, **NO** anula la garantía oficial (Knox se mantiene en 0x0) y **NO** requiere permisos Root. 

### Requisitos Previos:
1. Una computadora con **Windows**.
2. El celular de empresa Samsung encendido, desbloqueado, y con su PIN.
3. Un **cable USB** original o que soporte transferencia de datos.

### 🛠️ Paso 1: Descargar el Sofware en la PC

1. Ve a cualquier navegador en la computadora de sistemas.
2. Busca en Google **"SamFw FRP Tool"** y descarga la versión gratuita más reciente (generalmente un archivo .zip).
3. Descomprime la carpeta y abre el archivo ejecutable `SamFwTool.exe`.

### 🛠️ Paso 2: Preparar el Celular Samsung

1. Entra a los `Ajustes` normales del celular del vendedor y ve al final, a **Acerca del Teléfono** > **Información de Software**.
2. Toca 7 veces muy rápido sobre **"Número de compilación"** para activar las Opciones de Desarrollador.
3. Vuelve a la pantalla principal de Ajustes, entra al nuevo menú oculto **Opciones de desarrollador** que apareció hasta abajo.
4. Enciende el interruptor que dice **"Depuración por USB"**.
5. Conecta el celular a la computadora. Te saltará una ventana de alerta en la pantallita del celular preguntando "Permitir depuración USB", márcale "Permitir siempre desde esta computadora".

### 🛠️ Paso 3: Ejecutar el Salto de Región (CSC)

1. En el programa de la computadora (`SamFw Tool`), asegúrate de estar en la pestaña de arriba que diga **ADB**.
2. En la lista de botones de colores, busca y haz clic en el botón mágico **`Change CSC`**.
3. Te aparecerá un pequeño recuadro pop-up vacío pidiéndote un código.
4. Escribe exactamente **INS** (significa India) y dale en Change.
 *(Alternativamente, si el dispositivo protesta, puedes intentar **XXV** para Vietnam o **ILP** para Israel).*
5. ¡Magia! El celular recibirá la orden en fracciones de segundo y vas a ver cómo **se reinicia solo**.

### 🛠️ Paso 4: Encender la Grabación Silenciosa

1. Cuando el celular Samsung del vendedor vuelva a prender, **entra a la función de Marcar/Teléfono normal de Samsung** (el icono verde que traen de fábrica todos).
2. Toca los **tres puntitos (⋮)** en la esquina de arriba a la derecha y presiona **`Ajustes`**.
3. **¡FELICIDADES!** Vas a notar que acaba de aparecer una función dorada y escondida que antes no existía llamada **"Grabar Llamadas"**.
4. Entra a esa opción y simplemente toca en **`Grabar llamadas automáticamente`**.

---

## 🚀 Integración final con "Minuto a Minuto"

A partir de este momento, **el celular está hackeado legalmente.** Cada vez que el vendedor cuelgue una llamada de su rutina diaria, Samsung grabará la conversación de los dos de forma perfecta directamente desde la baseband, y depositará un brillante archivo de audio con ambas voces dentro del disco duro.

Ahí es donde entra nuestro Autómata de **Minuto a Minuto**:
* Nuestro Monitor Silencioso **detecta inmediatamente que la llamada del vendedor finalizó.**
* En vez de intentar grabar con micrófonos banales y enfrentarse al bloqueo de seguridad de Google, **la aplicación utiliza permisos avanzados para colarse en la memoria interna de Samsung, encontrar la carpeta nativa `/Call/`, y enviar ese archivo inmaculado y oficial directamente al servidor de la empresa.**
* Luego, nuestra integración con IA (Gemini) escucha un audio cristalino sin fallas de volumen y lo transcribe en su totalidad, alimentando las estadísticas de efectividad automáticamente.

### Entregar el Celular
Ya puedes instalar la App `Minuto a Minuto`, aceptar la nueva alerta roja del "Setup" si te lo pide,  y entregar el equipo operativo al Asesor Comercial de calle. Estará rindiendo al 100%.
