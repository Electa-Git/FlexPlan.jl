# Network formulations

Two different network formulations have been used in the FlexPlan package:
- `PowerModels.DCPPowerModel` is a linearised 'DC' power flow formulation that represents meshed AC/DC transmission networks;
- `FlexPlan.BFARadPowerModel` is a linearised 'DistFlow' formulation that represents radial AC distribution networks.

For the comprehensive formulation of the network equations, along with the detailed model for storage and demand flexibility, the readers are referred to the FlexPlan deliverable 1.2 ["Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability"](https://flexplan-project.eu/wp-content/uploads/2021/03/D1.2_20210325_V1.0.pdf)
```
@article{ergun2021probabilistic,
  title={Probabilistic optimization of T\&D systems planning with high grid flexibility and its scalability},
  author={Ergun, Hakan and Sperstad, Iver Bakken and Espen Flo, B{\o}dal and Siface, Dario and Pirovano, Guido and Rossi, Marco and Rossini, Matteo and Marmiroli, Benedetta and Agresti, Valentina and Costa, Matteo Paolo and others},
  year={2021}
}
```