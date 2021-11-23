# Data model

FlexPlan.jl extends data models of the ```PowerModels.jl``` and ```PowerModelsACDC.jl``` packages by including candidate storage devices, ```:ne_storage```, additional fields to parametrize the demand flexibility models which extend ```:load```, some additional parameters to both existing and candidate storage devices to represent external charging and discharging of storage, e.g., to represent natural inflow and dissipation of water in hydro storage, some additional parameters extending ```:gen``` to include air quality impact and  CO2 emission costs for the generators.

For the full data model please consult the FlexPlan deliverable 1.2 ["Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability"](https://flexplan-project.eu/wp-content/uploads/2021/03/D1.2_20210325_V1.0.pdf)

```
@article{ergun2021probabilistic,
  title={Probabilistic optimization of T\&D systems planning with high grid flexibility and its scalability},
  author={Ergun, Hakan and Sperstad, Iver Bakken and Espen Flo, B{\o}dal and Siface, Dario and Pirovano, Guido and Rossi, Marco and Rossini, Matteo and Marmiroli, Benedetta and Agresti, Valentina and Costa, Matteo Paolo and others},
  year={2021}
}
```