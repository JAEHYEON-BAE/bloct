## State Space
Let $N$ denote the total number of chapters in the subject.
The environment state at time step $t$ is defined as a matrix $\mathbf{s}_t \in \mathcal{S}$,
where $\mathcal{S} \subseteq [0,1] \times \mathbb{Z}_{\geq 0} \times \mathbb{Z}_{\geq 0}$ raised to the $N$-th power:
$$\mathbf{s}_t =
\begin{pmatrix}
R_0^{(t)}      & k_0^{(t)}      & \Delta t_0^{(t)}      \\
R_1^{(t)}      & k_1^{(t)}      & \Delta t_1^{(t)}      \\
\vdots         & \vdots         & \vdots                \\
R_{N-1}^{(t)} & k_{N-1}^{(t)} & \Delta t_{N-1}^{(t)}
\end{pmatrix}
\in \mathbb{R}^{N \times 3}$$

## Math appearance
Inline $x^2 + y^2 = z^2$, $\frac{a}{b}$ and $\sum_{i=0}^{N} x_i$.

$$
\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}
$$
